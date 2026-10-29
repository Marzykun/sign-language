import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One analysed camera frame from the native hand tracker.
class HandFrame {
  const HandFrame({
    required this.landmarks,
    required this.aspect,
    required this.timestampMs,
    required this.mirrored,
  });

  factory HandFrame.fromMap(Map<Object?, Object?> map) {
    final coords = (map['landmarks'] as List?)?.cast<num>() ?? const [];
    return HandFrame(
      landmarks: [
        for (var i = 0; i + 1 < coords.length; i += 2)
          Offset(coords[i].toDouble(), coords[i + 1].toDouble()),
      ],
      aspect: (map['aspect'] as num?)?.toDouble() ?? 1,
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
      mirrored: map['mirrored'] as bool? ?? false,
    );
  }

  /// 21 hand points, normalised to 0–1 of the upright, un-mirrored image. Empty if no hand.
  final List<Offset> landmarks;

  /// Image width / height.
  final double aspect;
  final int timestampMs;

  /// True for the front camera, whose preview is shown mirrored.
  final bool mirrored;
}

enum CameraPermission { granted, denied, permanentlyDenied }

/// Dart side of `SignCamera.kt`.
class SignCamera {
  static const _results = EventChannel('sign_camera/results');
  static const _control = MethodChannel('sign_camera/control');

  /// Errors arrive as [PlatformException]s with code `model`, `camera` or `landmarker`.
  static Stream<HandFrame> frames() => _results
      .receiveBroadcastStream()
      .map((event) => HandFrame.fromMap(event as Map<Object?, Object?>));

  static Future<void> switchCamera() => _control.invokeMethod('switchCamera');

  /// Asks for camera access if needed.
  static Future<CameraPermission> requestPermission() async {
    final status = await _control.invokeMethod<String>('requestPermission');
    return switch (status) {
      'granted' => CameraPermission.granted,
      'permanentlyDenied' => CameraPermission.permanentlyDenied,
      _ => CameraPermission.denied,
    };
  }

  /// Opens this app's page in system Settings.
  static Future<void> openSettings() => _control.invokeMethod('openSettings');
}

/// The native camera preview. Its image is 3:4 (portrait), matching the landmark coordinates.
class SignCameraPreview extends StatelessWidget {
  const SignCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('Camera is only supported on Android.'));
    }
    return const AndroidView(viewType: 'sign_camera/preview');
  }
}
