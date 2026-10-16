import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/debug_trace.dart';

/// The console tracer's formatting contract.
///
/// It exists so a multi-step flow reads as a legible sequence rather than forty
/// unaligned sentences, so the alignment and the field rendering are the
/// behaviour worth pinning.
void main() {
  const trace = DebugTrace('registration');

  late List<String> lines;
  late DebugPrintCallback original;

  setUp(() {
    lines = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
  });

  tearDown(() => debugPrint = original);

  test('every line carries the channel and a fixed-width verb', () {
    trace.step('draft', 'created');
    trace.ok('submit', 'accepted');

    expect(lines, [
      '[registration] ▸ DRAFT     created',
      '[registration] ✓ SUBMIT    accepted',
    ]);
    // The summaries start at the same column, which is the whole point.
    expect(lines[0].indexOf('created'), lines[1].indexOf('accepted'));
  });

  test('each severity has its own glyph', () {
    trace.step('a', 'x');
    trace.ok('a', 'x');
    trace.send('a', 'x');
    trace.warn('a', 'x');
    trace.fail('a', 'x');

    expect(lines.map((l) => l.split(' ')[1]), ['▸', '✓', '↑', '!', '✗']);
  });

  test('fields render as key=value after a double space', () {
    trace.ok('http', 'POST draft → 200', {'id': 'abc', 'fields': 46});

    expect(lines.single, endsWith('POST draft → 200  id=abc fields=46'));
  });

  test('a null field is omitted, not printed as "null"', () {
    // Otherwise it reads as a value the server actually sent.
    trace.ok('http', 'done', {'id': 'abc', 'correlation': null});

    expect(lines.single, endsWith('done  id=abc'));
    expect(lines.single, isNot(contains('null')));
  });

  test('an all-null field map adds nothing at all', () {
    trace.ok('http', 'done', {'a': null, 'b': null});

    expect(lines.single, endsWith('done'));
    // No field block at all -- not an empty one trailing the summary.
    expect(lines.single, isNot(contains('=')));
  });

  group('helpers', () {
    test('id truncates a UUID but leaves a short code alone', () {
      expect(
          DebugTrace.id('01a0412a-0b1c-7e79-8749-12f762b15627'), '01a0412a…');
      expect(DebugTrace.id('BP-202608'), 'BP-202608');
      expect(DebugTrace.id(null), '—');
      expect(DebugTrace.id(''), '—');
    });

    test('names joins for a human, and says so when empty', () {
      expect(DebugTrace.names(['city', 'postalCode', 'geo']),
          'city · postalCode · geo');
      expect(DebugTrace.names(const []), '—');
    });

    test('yesNo scans better than true/false in a dense line', () {
      expect(DebugTrace.yesNo(true), 'yes');
      expect(DebugTrace.yesNo(false), 'no');
    });
  });

  test('begin opens a titled block', () {
    trace.begin('depot registration');

    expect(lines, ['', '─────── depot registration ───────']);
  });

  test('a whole flow reads as a sequence', () {
    trace.begin('depot registration');
    trace.step('form', 'opened', {'step': '1/5 identity'});
    trace.ok('draft', 'resumed',
        {'id': DebugTrace.id('01a0412a-0b1c'), 'status': 'Draft'});
    trace.fail('step', '2/5 address', {
      'missing': DebugTrace.names(['city', 'geo'])
    });
    trace.send('http', 'POST submit');
    trace.ok('photos', 'all sent', {'sent': 3});

    expect(
        lines.skip(2).join('\n'),
        '''
[registration] ▸ FORM      opened  step=1/5 identity
[registration] ✓ DRAFT     resumed  id=01a0412a… status=Draft
[registration] ✗ STEP      2/5 address  missing=city · geo
[registration] ↑ HTTP      POST submit
[registration] ✓ PHOTOS    all sent  sent=3'''
            .trim());
  });
}
