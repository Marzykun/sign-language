import 'package:flutter_test/flutter_test.dart';
import 'package:sign_language/letter_composer.dart';

void main() {
  // Feeds [letter] every 33 ms (~30 fps) from [startMs] for [durationMs].
  int hold(LetterComposer c, String? letter, int startMs, int durationMs) {
    var t = startMs;
    for (; t <= startMs + durationMs; t += 33) {
      c.add(letter, t);
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

  test('a one-frame flicker does not reset the hold', () {
    final c = LetterComposer();
    final t = hold(c, 'B', 0, 600);
    c.add('R', t);
    hold(c, 'B', t + 33, 600);
    expect(c.text, 'B');
  });

  test('holding longer repeats the letter', () {
    final c = LetterComposer();
    hold(c, 'L', 0, 800 + 1200 + 300);
    expect(c.text, 'LL');
  });

  test('switching letters types each one', () {
    final c = LetterComposer();
    final t = hold(c, 'H', 0, 1300);
    hold(c, 'I', t, 1300);
    expect(c.text, 'HI');
  });

  test('no letter types nothing', () {
    final c = LetterComposer();
    hold(c, null, 0, 3000);
    expect(c.text, '');
    expect(c.candidate, isNull);
    expect(c.progress, 0);
  });

  test('progress fills while holding', () {
    final c = LetterComposer();
    hold(c, 'A', 0, 600);
    expect(c.candidate, 'A');
    expect(c.progress, greaterThan(0.3));
    expect(c.progress, lessThan(1));
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
    c.backspace();
    expect(c.text, 'A');
    c.clear();
    expect(c.text, '');
  });
}
