import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One analysed camera frame from the native recognizer.
class GestureFrame {
  const GestureFrame({
    required this.label,
    required this.score,
    required this.landmarks,
    required this.timestampMs,
    required this.mirrored,
  });

  factory GestureFrame.fromMap(Map<Object?, Object?> map) {
    final coords = (map['landmarks'] as List?)?.cast<num>() ?? const [];
    return GestureFrame(
      label: map['label'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      landmarks: [
        for (var i = 0; i + 1 < coords.length; i += 2)
          Offset(coords[i].toDouble(), coords[i + 1].toDouble()),
      ],
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
      mirrored: map['mirrored'] as bool? ?? false,
    );
  }

  final String label;
  final double score;

  /// 21 hand points, normalised to 0–1 of the upright, un-mirrored image.
  final List<Offset> landmarks;
  final int timestampMs;

  /// True for the front camera, whose preview is shown mirrored.
  final bool mirrored;
}

/// Dart side of `SignCamera.kt`.
class SignCamera {
  static const _results = EventChannel('sign_camera/results');
  static const _control = MethodChannel('sign_camera/control');

  /// Errors arrive as [PlatformException]s with code `model`, `camera` or `recognizer`.
  static Stream<GestureFrame> frames() => _results
      .receiveBroadcastStream()
      .map((event) => GestureFrame.fromMap(event as Map<Object?, Object?>));

  static Future<void> switchCamera() => _control.invokeMethod('switchCamera');
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
