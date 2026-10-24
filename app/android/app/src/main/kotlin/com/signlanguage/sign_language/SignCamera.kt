package com.signlanguage.sign_language

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizer
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Owns the camera and the MediaPipe gesture recognizer.
 *
 * Flutter talks to it over three channels:
 *  - platform view `sign_camera/preview`: the live camera preview
 *  - event channel `sign_camera/results`: one map per analysed frame
 *  - method channel `sign_camera/control`: `switchCamera`
 */
class SignCamera(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    messenger: BinaryMessenger,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var recognizer: GestureRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var previewView: PreviewView? = null
    private var useFrontCamera = true
    private var lastTimestampMs = 0L

    init {
        EventChannel(messenger, "sign_camera/results").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        MethodChannel(messenger, "sign_camera/control").setMethodCallHandler { call, result ->
            when (call.method) {
                "switchCamera" -> {
                    useFrontCamera = !useFrontCamera
                    bindCamera()
                    result.success(useFrontCamera)
                }
                else -> result.notImplemented()
            }
        }
    }

    val viewFactory = object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val view = PreviewView(context).apply {
                // TextureView-backed, which composes correctly inside Flutter.
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FIT_CENTER
            }
            previewView = view
            bindCamera()
            return object : PlatformView {
                override fun getView(): View = view
                override fun dispose() {
                    if (previewView === view) {
                        previewView = null
                        ProcessCameraProvider.getInstance(this@SignCamera.context).get().unbindAll()
                    }
                }
            }
        }
    }

    private fun bindCamera() {
        val view = previewView ?: return
        if (recognizer == null && !createRecognizer()) return

        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            val provider = providerFuture.get()
            // 4:3 matches the AspectRatio the Flutter side uses for the overlay.
            val resolution = ResolutionSelector.Builder()
                .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
                .build()
            val preview = Preview.Builder().setResolutionSelector(resolution).build()
                .also { it.setSurfaceProvider(view.surfaceProvider) }
            val analysis = ImageAnalysis.Builder()
                .setResolutionSelector(resolution)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
                .also { it.setAnalyzer(analysisExecutor, ::analyze) }
            val selector =
                if (useFrontCamera) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA

            provider.unbindAll()
            try {
                provider.bindToLifecycle(lifecycleOwner, selector, preview, analysis)
            } catch (e: Exception) {
                Log.e(TAG, "Camera bind failed", e)
                sendError("camera", e.message ?: "Could not open the camera")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun createRecognizer(): Boolean {
        return try {
            val options = GestureRecognizer.GestureRecognizerOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL_ASSET).build())
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(1)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener(::onResult)
                .setErrorListener { e -> sendError("recognizer", e.message ?: "Recognizer error") }
                .build()
            recognizer = GestureRecognizer.createFromOptions(context, options)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Could not load $MODEL_ASSET", e)
            sendError("model", "Could not load $MODEL_ASSET. See the README for how to add it.")
            false
        }
    }

    private fun analyze(image: ImageProxy) {
        // Recognition runs on the upright, un-mirrored image. The Flutter side mirrors the
        // landmark overlay for the front camera, which keeps handedness correct for the model.
        val bitmap = image.use { proxy ->
            val raw = proxy.toBitmap()
            val rotation = proxy.imageInfo.rotationDegrees
            if (rotation == 0) raw else {
                val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
                Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, matrix, true)
            }
        }
        // MediaPipe rejects timestamps that don't strictly increase.
        val timestampMs = maxOf(SystemClock.uptimeMillis(), lastTimestampMs + 1)
        lastTimestampMs = timestampMs
        recognizer?.recognizeAsync(BitmapImageBuilder(bitmap).build(), timestampMs)
    }

    private fun onResult(result: GestureRecognizerResult, input: MPImage) {
        val gesture = result.gestures().firstOrNull()?.firstOrNull()
        val landmarks = result.landmarks().firstOrNull()?.flatMap { listOf(it.x().toDouble(), it.y().toDouble()) }
        val event = mapOf(
            "label" to (gesture?.categoryName() ?: ""),
            "score" to (gesture?.score()?.toDouble() ?: 0.0),
            "landmarks" to (landmarks ?: emptyList<Double>()),
            "timestampMs" to result.timestampMs(),
            "mirrored" to useFrontCamera,
        )
        mainHandler.post { eventSink?.success(event) }
    }

    private fun sendError(code: String, message: String) {
        mainHandler.post { eventSink?.error(code, message, null) }
    }

    fun close() {
        recognizer?.close()
        recognizer = null
        analysisExecutor.shutdown()
    }

    companion object {
        private const val TAG = "SignCamera"
        const val MODEL_ASSET = "gesture_recognizer.task"
    }
}
