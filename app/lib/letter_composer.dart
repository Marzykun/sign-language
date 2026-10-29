/// Turns a noisy stream of per-frame letters into typed text.
///
/// A letter has to be held steadily for [holdMs] before it's typed. Keep
/// holding and it repeats every [repeatMs], which is how double letters
/// ("LL") work. Flickers shorter than [graceMs] are ignored so one bad frame
/// doesn't reset the hold.
class LetterComposer {
  LetterComposer({this.holdMs = 800, this.repeatMs = 1200, this.graceMs = 200});

  final int holdMs;
  final int repeatMs;
  final int graceMs;

  String _text = '';
  String? _candidate;
  int _candidateSinceMs = 0;
  int _commitCount = 0;
  int? _otherSinceMs;
  double _progress = 0;

  String get text => _text;

  /// The letter currently being held, or null.
  String? get candidate => _candidate;

  /// How close the current hold is to typing, from 0 to 1.
  double get progress => _progress;

  /// Feeds one frame's letter (null for no letter). Returns true if [text] changed.
  bool add(String? letter, int timestampMs) {
    if (letter != _candidate) {
      _otherSinceMs ??= timestampMs;
      if (timestampMs - _otherSinceMs! < graceMs) return false;
      _candidate = letter;
      _candidateSinceMs = timestampMs;
      _commitCount = 0;
      _otherSinceMs = null;
      _progress = 0;
      return false;
    }
    _otherSinceMs = null;

    if (letter == null) {
      _progress = 0;
      return false;
    }

    final elapsed = timestampMs - _candidateSinceMs;
    final previousAt = _commitCount == 0 ? 0 : holdMs + (_commitCount - 1) * repeatMs;
    final nextAt = holdMs + _commitCount * repeatMs;
    _progress = ((elapsed - previousAt) / (nextAt - previousAt)).clamp(0.0, 1.0);
    if (elapsed < nextAt) return false;

    _commitCount++;
    _progress = 0;
    _text += letter;
    return true;
  }

  void addSpace() {
    if (_text.isNotEmpty && !_text.endsWith(' ')) _text += ' ';
  }

  void backspace() {
    if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
  }

  void clear() => _text = '';
}
