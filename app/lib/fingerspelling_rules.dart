import 'dart:math' as math;
import 'dart:ui';

enum FingerState { straight, bent, curled }

enum Pointing { up, sideways, down }

/// Reads ASL fingerspelling letters from the 21 MediaPipe hand points using
/// hand-written geometry rules, with no trained model.
///
/// Point indices: 0 wrist; thumb 1–4; index 5–8; middle 9–12; ring 13–16;
/// pinky 17–20 (each finger runs knuckle → tip).
///
/// Supported: A B C D E F G H I K L O P Q R S U V W X Y.
/// J and Z need motion and M N T hide the thumb, so they're not attempted.
class FingerspellingRules {
  FingerspellingRules._(this._p) : _palm = (_p[9] - _p[0]).distance;

  /// [points] are normalised image coordinates; [aspect] is image width / height,
  /// used so that distances and angles aren't skewed by a non-square image.
  static String? classify(List<Offset> points, {double aspect = 1}) {
    if (points.length < 21) return null;
    final scaled = [for (final p in points) Offset(p.dx * aspect, p.dy)];
    final hand = FingerspellingRules._(scaled);
    if (hand._palm <= 0) return null;
    return hand._letter();
  }

  final List<Offset> _p;
  final double _palm;

  String? _letter() {
    final index = _finger(0), middle = _finger(1), ring = _finger(2), pinky = _finger(3);
    bool all(List<FingerState> fingers, FingerState s) => fingers.every((f) => f == s);
    const straight = FingerState.straight, curled = FingerState.curled, bent = FingerState.bent;
    final thumbOut = _dist(4, 5) > 0.65 * _palm;
    final lowerCurled = all([ring, pinky], curled);

    switch (_pointing()) {
      case Pointing.sideways:
        if (index == straight && middle == straight && lowerCurled) return 'H';
        if (index == straight && middle == curled && lowerCurled) return 'G';
        return null;
      case Pointing.down:
        if (index == straight && middle == straight && lowerCurled) return 'P';
        if (index == straight && middle == curled && lowerCurled && thumbOut) return 'Q';
        return null;
      case Pointing.up:
        break;
    }

    if (_touching(4, 8) && all([middle, ring, pinky], straight)) return 'F';
    if (all([index, middle, ring, pinky], straight)) return thumbOut ? null : 'B';
    if (all([index, middle, ring], straight) && pinky != straight) return 'W';

    if (index == straight && middle == straight && ring != straight && pinky != straight) {
      if (_crossed()) return 'R';
      if ((_p[4] - (_p[6] + _p[10]) / 2).distance < 0.35 * _palm) return 'K';
      return _angleBetween(_p[8] - _p[5], _p[12] - _p[9]) > 15 ? 'V' : 'U';
    }

    if (index == straight && all([middle, ring, pinky], curled)) {
      if (thumbOut) return 'L';
      if (_touching(4, 12) || _touching(4, 11)) return 'D';
      return null;
    }

    if (pinky == straight && all([index, middle, ring], curled)) return thumbOut ? 'Y' : 'I';

    if (index == bent && all([middle, ring, pinky], curled) && !thumbOut) return 'X';
    // Ring and pinky often read as curled in a C or O, so only the front two must be bent.
    if (all([index, middle], bent) && ring != straight && pinky != straight) {
      return _touching(4, 8) ? 'O' : 'C';
    }

    if (all([index, middle, ring, pinky], curled)) {
      if (_acrossPalm(_p[4]) > 0.9) return 'A';
      final tipsY = (_p[8].dy + _p[12].dy + _p[16].dy + _p[20].dy) / 4;
      // Image y grows downwards: a smaller y means the thumb sits higher than the fingertips.
      return _p[4].dy < tipsY ? 'S' : 'E';
    }
    return null;
  }

  FingerState _finger(int finger) {
    final mcp = 5 + finger * 4, pip = mcp + 1, dip = mcp + 2, tip = mcp + 3;
    final tipFromWrist = _dist(tip, 0), pipFromWrist = _dist(pip, 0);
    if (tipFromWrist < pipFromWrist) return FingerState.curled;
    if (_angleAt(mcp, pip, dip) > 150 && _angleAt(pip, dip, tip) > 140) return FingerState.straight;
    return FingerState.bent;
  }

  Pointing _pointing() {
    final v = _p[9] - _p[0];
    if (-v.dy > v.dx.abs()) return Pointing.up;
    if (v.dy > v.dx.abs()) return Pointing.down;
    return Pointing.sideways;
  }

  /// Index and middle fingertips have swapped sides, as in R.
  bool _crossed() {
    final across = _p[5] - _p[17];
    return _dot(_p[8] - _p[12], across) < 0;
  }

  /// Where [point] falls across the palm: 0 at the pinky knuckle, 1 at the index knuckle.
  /// Works the same for left and right hands.
  double _acrossPalm(Offset point) {
    final across = _p[5] - _p[17];
    return _dot(point - _p[17], across) / _dot(across, across);
  }

  bool _touching(int a, int b) => _dist(a, b) < 0.3 * _palm;

  double _dist(int a, int b) => (_p[a] - _p[b]).distance;

  /// Angle in degrees at joint [b] between the segments to [a] and [c].
  double _angleAt(int a, int b, int c) => _angleBetween(_p[a] - _p[b], _p[c] - _p[b]);

  static double _angleBetween(Offset u, Offset v) {
    final lengths = u.distance * v.distance;
    if (lengths == 0) return 0;
    return math.acos((_dot(u, v) / lengths).clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  static double _dot(Offset u, Offset v) => u.dx * v.dx + u.dy * v.dy;
}
