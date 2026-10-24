import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language/sign_camera.dart';

void main() {
  test('parses a native result map', () {
    final frame = GestureFrame.fromMap({
      'label': 'A',
      'score': 0.87,
      'landmarks': [0.1, 0.2, 0.3, 0.4],
      'timestampMs': 1234,
      'mirrored': true,
    });
    expect(frame.label, 'A');
    expect(frame.score, closeTo(0.87, 1e-9));
    expect(frame.landmarks, [const Offset(0.1, 0.2), const Offset(0.3, 0.4)]);
    expect(frame.timestampMs, 1234);
    expect(frame.mirrored, isTrue);
  });

  test('handles a frame with no hand', () {
    final frame = GestureFrame.fromMap({'label': '', 'score': 0, 'landmarks': [], 'timestampMs': 5});
    expect(frame.label, '');
    expect(frame.landmarks, isEmpty);
    expect(frame.mirrored, isFalse);
  });
}
