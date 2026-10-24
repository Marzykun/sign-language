import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language/letter_composer.dart';

void main() {
  // Feeds [label] every 33 ms (~30 fps) from [startMs] for [durationMs].
  int hold(LetterComposer c, String label, int startMs, int durationMs, {double score = 0.9}) {
    var t = startMs;
    for (; t <= startMs + durationMs; t += 33) {
      c.add(label, score, t);
    }
    return t;
  }

  test('types a letter after it is held long enough', () {
    final c = LetterComposer();
    hold(c, 'A', 0, 900);
    expect(c.text, '');
    hold(c, 'A', 933, 200);
    expect(c.text, 'A');
  });

  test('ignores low-confidence predictions', () {
    final c = LetterComposer();
    hold(c, 'A', 0, 3000, score: 0.3);
    expect(c.text, '');
  });

  test('a one-frame flicker does not reset the hold', () {
    final c = LetterComposer();
    var t = hold(c, 'B', 0, 600);
    c.add('R', 0.9, t);
    hold(c, 'B', t + 33, 600);
    expect(c.text, 'B');
  });

  test('holding longer repeats the letter', () {
    final c = LetterComposer();
    hold(c, 'L', 0, 800 + 1200 + 300);
    expect(c.text, 'LL');
  });

  test('switching signs types each one', () {
    final c = LetterComposer();
    var t = hold(c, 'H', 0, 1300);
    t = hold(c, 'I', t, 1300);
    expect(c.text, 'HI');
  });

  test('space and del gestures edit the text', () {
    final c = LetterComposer();
    var t = hold(c, 'H', 0, 1300);
    t = hold(c, 'space', t, 1300);
    expect(c.text, 'H ');
    hold(c, 'del', t, 1300);
    expect(c.text, 'H');
  });

  test('non-letter labels are never typed', () {
    final c = LetterComposer();
    var t = hold(c, 'none', 0, 3000);
    hold(c, 'Thumb_Up', t, 3000);
    expect(c.text, '');
    expect(c.candidate, isNull);
  });

  test('manual controls', () {
    final c = LetterComposer()
      ..addSpace()
      ..backspace();
    expect(c.text, '', reason: 'no leading space, backspace on empty is safe');
    hold(c, 'A', 0, 1300);
    c
      ..addSpace()
      ..addSpace();
    expect(c.text, 'A ');
    c.clear();
    expect(c.text, '');
  });
}
