import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language/sign_camera.dart';

void main() {
  test('parses a native result map', () {
    final frame = HandFrame.fromMap({
      'landmarks': [0.1, 0.2, 0.3, 0.4],
      'aspect': 0.75,
      'timestampMs': 1234,
      'mirrored': true,
    });
    expect(frame.landmarks, [const Offset(0.1, 0.2), const Offset(0.3, 0.4)]);
    expect(frame.aspect, 0.75);
    expect(frame.timestampMs, 1234);
    expect(frame.mirrored, isTrue);
  });

  test('handles a frame with no hand', () {
    final frame = HandFrame.fromMap({'landmarks': [], 'timestampMs': 5});
    expect(frame.landmarks, isEmpty);
    expect(frame.aspect, 1);
    expect(frame.mirrored, isFalse);
  });
}
