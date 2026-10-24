package com.signlanguage.sign_language

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var signCamera: SignCamera? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val camera = SignCamera(this, this, flutterEngine.dartExecutor.binaryMessenger)
        flutterEngine.platformViewsController.registry.registerViewFactory("sign_camera/preview", camera.viewFactory)
        signCamera = camera
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        signCamera?.close()
        signCamera = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
