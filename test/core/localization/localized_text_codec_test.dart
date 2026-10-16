import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text_codec.dart';

/// The codec is the one place that knows how a bilingual field is spelled on
/// the wire. Its whole value is that every model parses `null`, `''` and
/// "Khmer missing" identically — so these tests pin exactly those three cases,
/// which is where per-model hand-rolled parsing used to drift apart.
void main() {
  group('readName (catalog convention)', () {
    test('reads the JSON spelling', () {
      final text = LocalizedTextCodec.readName(
          {'name': 'Gypsum Board', 'nameKh': 'ផ្ទាំងជីប'});
      expect(text.en, 'Gypsum Board');
      expect(text.km, 'ផ្ទាំងជីប');
    });

    test('reads the Drift row spelling from the same call', () {
      final text = LocalizedTextCodec.readName(
          {'name': 'Gypsum Board', 'name_kh': 'ផ្ទាំងជីប'});
      expect(text.km, 'ផ្ទាំងជីប');
    });

    test('a feed with no Khmer resolves to English rather than a blank row',
        () {
      final text = LocalizedTextCodec.readName({'name': 'Steel Plate'});
      expect(text.km, isEmpty);
      expect(text.resolve('km'), 'Steel Plate');
    });
  });

  group('readBusinessName (depot-master convention)', () {
    test('prefers enName/khName when SAP populated them', () {
      final text = LocalizedTextCodec.readBusinessName(
        {'enName': 'Golden Sky Depot Co., Ltd', 'khName': 'ឃ្លាំង មាសមេឃ'},
        fallbackEn: 'Golden Sky Depot',
      );
      expect(text.en, 'Golden Sky Depot Co., Ltd');
      expect(text.km, 'ឃ្លាំង មាសមេឃ');
    });

    // The case that makes this safe to adopt on the directory: `shopName` is
    // populated for every row, SAP's `name1` is not.
    test('falls back to the display name when SAP left name1 blank', () {
      final text = LocalizedTextCodec.readBusinessName(
        {'enName': '', 'khName': 'ឃ្លាំង មាសមេឃ'},
        fallbackEn: 'Golden Sky Depot',
      );
      expect(text.en, 'Golden Sky Depot');
      expect(text.km, 'ឃ្លាំង មាសមេឃ');
    });
  });

  group('of / ofOrNull', () {
    test('normalises null to empty and trims', () {
      expect(LocalizedTextCodec.of('  Steel  ', null).en, 'Steel');
      expect(LocalizedTextCodec.of('Steel', null).km, isEmpty);
    });

    // "absent" and "blank in both languages" must not render differently.
    test('ofOrNull collapses a wholly-empty pair to null', () {
      expect(LocalizedTextCodec.ofOrNull(null, null), isNull);
      expect(LocalizedTextCodec.ofOrNull('  ', ''), isNull);
      expect(LocalizedTextCodec.ofOrNull('x', null), isNotNull);
    });
  });
}
