import 'package:flutter/material.dart';

/// Draws the 21-point hand skeleton over the camera preview.
class LandmarkPainter extends CustomPainter {
  LandmarkPainter({required this.landmarks, required this.mirrored, required this.color});

  final List<Offset> landmarks;
  final bool mirrored;
  final Color color;

  // MediaPipe hand topology: thumb, four fingers, then the palm.
  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [5, 9], [9, 10], [10, 11], [11, 12],
    [9, 13], [13, 14], [14, 15], [15, 16],
    [13, 17], [17, 18], [18, 19], [19, 20],
    [0, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.length < 21) return;
    Offset toCanvas(Offset p) =>
        Offset((mirrored ? 1 - p.dx : p.dx) * size.width, p.dy * size.height);

    final line = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final c in _connections) {
      canvas.drawLine(toCanvas(landmarks[c[0]]), toCanvas(landmarks[c[1]]), line);
    }
    final dot = Paint()..color = Colors.white;
    for (final p in landmarks) {
      canvas.drawCircle(toCanvas(p), 4, dot);
    }
  }

  @override
  bool shouldRepaint(LandmarkPainter old) =>
      old.landmarks != landmarks || old.mirrored != mirrored || old.color != color;
}
