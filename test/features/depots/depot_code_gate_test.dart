import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_code_lookup_cubit.dart';

/// The gate on the by-code lookup.
///
/// `GET /depots/by-code/{code}` can reach the ERP, so it must never sit on
/// the keystroke path the way local search does. The integration guide is
/// explicit: *"Only on an explicit full-code lookup. Never on the keystroke
/// path."* This predicate is what enforces the "full code" half.
void main() {
  group('offers a lookup for code-shaped terms', () {
    for (final code in const [
      '6100000017', // a SAP depot number
      'BP-202608-00002', // a generated platform code
      'ISI-PP0005', // an ISI code
      '610000', // the shortest thing worth asking about
    ]) {
      test('"$code"', () => expect(looksLikeDepotCode(code), isTrue));
    }

    test('surrounding whitespace does not matter', () {
      expect(looksLikeDepotCode('  6100000017  '), isTrue);
    });
  });

  group('does not offer one for anything a rep might be typing as a name', () {
    for (final term in const [
      'ដេប៉ូ', // Khmer shop name
      'ដេប៉ូ តាំង', // two Khmer words
      'Toul Kork Depot', // a Latin name with spaces
      'depot', // no digits, so not a code
      '610', // too short to be unambiguous
      '', // empty
      '   ', // whitespace only
      'Sok Heng Hardware',
    ]) {
      test('"$term"', () => expect(looksLikeDepotCode(term), isFalse));
    }

    test('a phone-shaped term with spaces is not treated as a code', () {
      // Spaces disqualify it, so typing a phone number does not fire a call
      // that can reach the ERP -- local search covers phone matching.
      expect(looksLikeDepotCode('012 345 678'), isFalse);
    });
  });

  test('a term needs at least one digit', () {
    // Guards against a long Latin name being mistaken for a code.
    expect(looksLikeDepotCode('ABCDEFGH'), isFalse);
    expect(looksLikeDepotCode('ABCDEFG1'), isTrue);
  });
}
