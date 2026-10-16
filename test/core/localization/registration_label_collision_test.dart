import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two fields on the registration form must never share a label.
///
/// ## The defect this guards
///
/// `grouping` and `depot_group` are unrelated SAP fields — the BP **account
/// group** (`Z001` Local / `Z002` Export / `Z003` One-time, sent as
/// `partnerGroup` + `accountGroup`) and the **depot group** (`01`–`08`
/// End-User … Exporter, sent as `depotGroup`). They sit on different steps
/// and come from different sources: one is a built-in list because the ERP
/// publishes no catalogue for it, the other is live from
/// `GET /mobile/depots/references`.
///
/// They were labelled "Depot grouping" and "Depot group" in English, and
/// **identically** — `ក្រុមអតិថិជន` — in Khmer. A reader could not tell which
/// field they were looking at, and reasonably concluded the live catalogue had
/// not been wired at all.
///
/// A label collision between two dropdowns is therefore treated as a defect,
/// not a style question.
void main() {
  Map<String, dynamic> addDepotSection(String languageCode) {
    final raw = File('assets/lang/$languageCode.json').readAsStringSync();
    return (jsonDecode(raw) as Map<String, dynamic>)['add_depot']
        as Map<String, dynamic>;
  }

  /// The labelled inputs on the registration form that a rep picks between.
  /// Adding a dropdown means adding its key here.
  const dropdownLabelKeys = <String>[
    'grouping',
    'title_field',
    'depot_group',
    'price_group_auto',
    'sales_org',
    'sales_office',
    'sales_group',
    'distribution_channel',
    'delivery_priority',
    'shipping_condition',
    'payment_term',
    'tax_class',
    'currency',
  ];

  for (final language in const ['en', 'km']) {
    group('$language.json', () {
      test('every dropdown label is present', () {
        final section = addDepotSection(language);
        for (final key in dropdownLabelKeys) {
          expect(section[key], isA<String>(), reason: 'missing: $key');
          expect((section[key] as String).trim(), isNotEmpty, reason: key);
        }
      });

      test('no two dropdown labels are identical', () {
        final section = addDepotSection(language);
        final seen = <String, String>{};

        for (final key in dropdownLabelKeys) {
          final label = (section[key] as String).trim();
          final clash = seen[label];
          expect(
            clash,
            isNull,
            reason: 'ambiguous: "$key" and "$clash" both read "$label" — two '
                'different SAP fields a rep cannot tell apart',
          );
          seen[label] = key;
        }
      });

      test('the account group and the depot group read differently', () {
        // The specific pair that collided, named so a regression points
        // straight at the cause rather than at a generic duplicate.
        final section = addDepotSection(language);

        expect(section['grouping'], isNot(section['depot_group']));
      });
    });
  }

  test('the two labels differ from each other in every language', () {
    // A fix applied to English only would leave a Khmer-speaking rep facing
    // exactly the original defect.
    for (final language in const ['en', 'km']) {
      final section = addDepotSection(language);
      expect(section['grouping'], isNot(section['depot_group']),
          reason: language);
    }
  });
}
