import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language/fingerspelling_rules.dart';

/// Builds synthetic 21-point hands in a palm-length-1 coordinate space, wrist at the
/// origin, fingers pointing up (negative y, like image coordinates).
enum F { straight, bent, curled }

const _knuckles = [Offset(0.35, -1.0), Offset(0.1, -1.05), Offset(-0.12, -1.0), Offset(-0.32, -0.9)];

List<Offset> hand({
  required List<F> fingers,
  required Offset thumbTip,
  List<double> tilts = const [0, 0, 0, 0],
}) {
  final points = <Offset>[
    Offset.zero,
    const Offset(0.3, -0.25),
    const Offset(0.5, -0.45),
    (const Offset(0.5, -0.45) + thumbTip) / 2,
    thumbTip,
  ];
  for (var i = 0; i < 4; i++) {
    final mcp = _knuckles[i];
    switch (fingers[i]) {
      case F.straight:
        final rad = tilts[i] * math.pi / 180;
        final dir = Offset(math.sin(rad), -math.cos(rad));
        points.addAll([mcp, mcp + dir * 0.45, mcp + dir * 0.73, mcp + dir * 0.95]);
      case F.bent:
        final pip = mcp + const Offset(0, -0.4);
        final dip = pip + const Offset(0.2, -0.05);
        points.addAll([mcp, pip, dip, dip + const Offset(0.15, 0.1)]);
      case F.curled:
        points.addAll([mcp, mcp + const Offset(0, -0.35), mcp + const Offset(0, -0.15), mcp + const Offset(0, 0.1)]);
    }
  }
  return points;
}

/// Places the hand in a 0–1 image: rotated by [degrees], optionally mirrored.
List<Offset> place(List<Offset> points, {double degrees = 0, bool mirror = false}) {
  final rad = degrees * math.pi / 180;
  return [
    for (final p in points)
      () {
        final x = p.dx * math.cos(rad) - p.dy * math.sin(rad);
        final y = p.dx * math.sin(rad) + p.dy * math.cos(rad);
        return Offset(0.5 + (mirror ? -x : x) * 0.2, 0.6 + y * 0.2);
      }(),
  ];
}

String? classify(List<Offset> points, {double degrees = 0, bool mirror = false}) =>
    FingerspellingRules.classify(place(points, degrees: degrees, mirror: mirror));

void main() {
  const s = F.straight, b = F.bent, c = F.curled;
  const thumbIn = Offset(0.0, -0.6);
  const thumbOut = Offset(0.95, -0.55);

  final poses = <String, List<Offset>>{
    'A': hand(fingers: [c, c, c, c], thumbTip: const Offset(0.5, -1.2)),
    'B': hand(fingers: [s, s, s, s], thumbTip: thumbIn),
    'C': hand(fingers: [b, b, b, b], thumbTip: const Offset(0.8, -0.6)),
    'D': hand(fingers: [s, c, c, c], thumbTip: const Offset(0.12, -0.93)),
    'E': hand(fingers: [c, c, c, c], thumbTip: const Offset(0.1, -0.75)),
    'F': hand(fingers: [b, s, s, s], thumbTip: const Offset(0.68, -1.3)),
    'I': hand(fingers: [c, c, c, s], thumbTip: thumbIn),
    'K': hand(fingers: [s, s, c, c], thumbTip: const Offset(0.225, -1.475), tilts: [12, -12, 0, 0]),
    'L': hand(fingers: [s, c, c, c], thumbTip: thumbOut),
    'O': hand(fingers: [b, b, b, b], thumbTip: const Offset(0.7, -1.35)),
    'R': hand(fingers: [s, s, c, c], thumbTip: thumbIn, tilts: [-10, 10, 0, 0]),
    'S': hand(fingers: [c, c, c, c], thumbTip: const Offset(0.1, -1.25)),
    'U': hand(fingers: [s, s, c, c], thumbTip: thumbIn),
    'V': hand(fingers: [s, s, c, c], thumbTip: thumbIn, tilts: [12, -12, 0, 0]),
    'W': hand(fingers: [s, s, s, c], thumbTip: thumbIn, tilts: [12, 0, -12, 0]),
    'X': hand(fingers: [b, c, c, c], thumbTip: const Offset(0.05, -0.75)),
    'Y': hand(fingers: [c, c, c, s], thumbTip: thumbOut),
  };

  group('upright letters', () {
    for (final MapEntry(key: letter, value: pose) in poses.entries) {
      test(letter, () => expect(classify(pose), letter));
      test('$letter with the other hand', () => expect(classify(pose, mirror: true), letter));
    }
  });

  group('sideways and downward letters', () {
    test('G', () => expect(classify(poses['L']!, degrees: -90), 'G'));
    test('H', () => expect(classify(poses['U']!, degrees: -90), 'H'));
    test('P', () => expect(classify(poses['U']!, degrees: 180), 'P'));
    test('Q', () => expect(classify(poses['L']!, degrees: 180), 'Q'));
  });

  test('an open hand with the thumb out is not a letter', () {
    expect(classify(hand(fingers: [s, s, s, s], thumbTip: thumbOut)), isNull);
  });

  test('needs all 21 points', () {
    expect(FingerspellingRules.classify(const []), isNull);
    expect(FingerspellingRules.classify(place(poses['B']!).sublist(0, 20)), isNull);
  });

  test('corrects for a non-square image', () {
    const aspect = 0.75;
    final squashed = [for (final p in place(poses['V']!)) Offset(p.dx / aspect, p.dy)];
    expect(FingerspellingRules.classify(squashed, aspect: aspect), 'V');
  });
}
