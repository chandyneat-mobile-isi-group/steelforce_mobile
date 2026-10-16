/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
///
/// The "no order" reasons as `GET /visits/check-out-reasons` sends them
/// (`check-in-check-out-mobile.md` §6), in both languages.
library;

import 'package:steelforce/core/utils/typedefs.dart';

const List<DataMap> demoCheckOutReasonsJson = [
  {
    'code': 'stockStillEnough',
    'nameEn': 'Shop still has enough stock',
    'nameKm': 'ហាងនៅមានស្តុកគ្រប់គ្រាន់',
    'requiresNote': false,
    'sort': 1,
  },
  {
    'code': 'ownerNotAvailable',
    'nameEn': 'Owner / buyer not available',
    'nameKm': 'ម្ចាស់ហាង ឬអ្នកទិញមិននៅ',
    'requiresNote': false,
    'sort': 2,
  },
  {
    'code': 'priceTooHigh',
    'nameEn': 'Price too high',
    'nameKm': 'តម្លៃខ្ពស់ពេក',
    'requiresNote': false,
    'sort': 3,
  },
  {
    'code': 'orderedByPhone',
    'nameEn': 'Will order by phone later',
    'nameKm': 'នឹងបញ្ជាទិញតាមទូរសព្ទពេលក្រោយ',
    'requiresNote': false,
    'sort': 4,
  },
  {
    'code': 'boughtFromCompetitor',
    'nameEn': 'Bought from a competitor',
    'nameKm': 'បានទិញពីដៃគូប្រកួតប្រជែង',
    'requiresNote': true,
    'sort': 5,
  },
  {
    'code': 'other',
    'nameEn': 'Other',
    'nameKm': 'ផ្សេងៗ',
    'requiresNote': true,
    'sort': 99,
  },
];
