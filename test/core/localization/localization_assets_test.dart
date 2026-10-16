import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors `LocalizationService._flatten`: nested objects collapse to
/// "parent.child.key", which is the form every `.tr` call site uses.
void _flatten(
    Map<String, dynamic> map, String prefix, Map<String, String> out) {
  map.forEach((key, value) {
    final flatKey = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      _flatten(value, flatKey, out);
    } else {
      out[flatKey] = value.toString();
    }
  });
}

Map<String, String> _load(String code) {
  final raw = File('assets/lang/$code.json').readAsStringSync();
  final out = <String, String>{};
  _flatten(json.decode(raw) as Map<String, dynamic>, '', out);
  return out;
}

final _placeholder = RegExp(r'\{(\w+)\}');

void main() {
  // The app ships English and Khmer only.
  const locales = ['en', 'km'];

  late Map<String, Map<String, String>> bundles;

  setUpAll(() {
    bundles = {for (final code in locales) code: _load(code)};
  });

  test('every locale asset parses and is non-empty', () {
    for (final code in locales) {
      expect(bundles[code], isNotEmpty,
          reason: '$code.json flattened to zero '
              'keys — LocalizationService would fall back to raw keys everywhere');
    }
  });

  test('every English key has a Khmer translation', () {
    // `translate()` returns the key itself when a lookup misses, so a gap here
    // surfaces to the user as raw text like "products.status.low_stock".
    final missing = bundles['en']!
        .keys
        .where((key) => !bundles['km']!.containsKey(key))
        .toList()
      ..sort();

    expect(missing, isEmpty,
        reason:
            'these keys render as raw text in Khmer:\n${missing.join('\n')}');
  });

  test('placeholders are consistent across locales', () {
    // `translateWithParams` substitutes by name. A placeholder present in one
    // locale and absent in another silently drops the value.
    final mismatched = <String>[];

    for (final entry in bundles['en']!.entries) {
      final khmer = bundles['km']![entry.key];
      if (khmer == null) continue;

      final inEnglish =
          _placeholder.allMatches(entry.value).map((m) => m[1]!).toSet();
      final inKhmer = _placeholder.allMatches(khmer).map((m) => m[1]!).toSet();

      // Khmer legitimately drops some placeholders — `my_visits.ordinal.template`
      // renders "ទី{n}" because Khmer ordinals take no English-style suffix. So
      // only flag placeholders Khmer uses that English never supplies, which is
      // always a bug: nothing will ever fill them in.
      final unfillable = inKhmer.difference(inEnglish);
      if (unfillable.isNotEmpty) {
        mismatched.add('${entry.key}: km expects $unfillable, en supplies '
            '$inEnglish');
      }
    }

    expect(mismatched, isEmpty, reason: mismatched.join('\n'));
  });

  test('only the localization service defines the `.tr` extension', () {
    // The regression this pins down. `product_result_card.dart` declared its
    // own `extension StringTranslateX on String { String get tr => this; }`
    // and did not import the real one, so every `.tr` in that file resolved to
    // the stub, returned the key verbatim, and never changed with the language.
    // Because Dart resolves extensions per-library, this is invisible at the
    // call site and the analyzer has nothing to complain about.
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = entity.readAsStringSync();
      if (!RegExp(r'\bget\s+tr\b').hasMatch(source)) continue;

      final normalized = entity.path.replaceAll(r'\', '/');
      if (normalized == 'lib/core/localization/localization_services.dart') {
        continue;
      }
      offenders.add(normalized);
    }

    expect(offenders, isEmpty,
        reason: 'these files shadow the real `.tr` and will render raw keys:\n'
            '${offenders.join('\n')}');
  });
}
