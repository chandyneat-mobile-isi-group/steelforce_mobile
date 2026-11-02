import 'dart:convert';

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_sales_area.dart';

/// Reads and writes `salesAreas` from `GET /mobile/depots` in the server's own
/// shape, which is also what the local `sales_areas_json` column holds:
///
/// ```json
/// { "salesOrg": {"code": "0001", "nameEn": "Phnom Penh (ISI)"},
///   "distributionChannel": {"code": "50", "nameEn": "Contractor"},
///   "division": "10",
///   "paymentTerms": {"code": "TCOD", "nameEn": "COD-Cash on Delivery"},
///   "creditLimit": 0, "creditLimitDate": "00000000", "creditTermDays": null }
/// ```
abstract final class DepotSalesAreaModel {
  /// Null when the payload has no `salesAreas` key — "not sent", which must
  /// not wipe a list stored from an earlier answer.
  static List<DepotSalesArea>? listFrom(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final a in raw.whereType<Map>()) _fromJson(a.cast<String, dynamic>())
    ];
  }

  static DepotSalesArea _fromJson(DataMap json) {
    final org = _map(json['salesOrg']);
    final channel = _map(json['distributionChannel']);
    final terms = _map(json['paymentTerms']);
    return DepotSalesArea(
      salesOrgCode: _text(org['code']),
      salesOrgName: _text(org['nameEn']),
      channelCode: _text(channel['code']),
      channelName: _text(channel['nameEn']),
      division: _text(json['division']),
      paymentTermsCode: _text(terms['code']),
      paymentTermsName: _text(terms['nameEn']),
      creditLimit: _number(json['creditLimit']),
      creditLimitDate: _sapDate(json['creditLimitDate']),
      creditTermDays: _number(json['creditTermDays'])?.toInt(),
    );
  }

  static String? encode(List<DepotSalesArea>? areas) => areas == null
      ? null
      : jsonEncode([
          for (final a in areas)
            {
              'salesOrg': {'code': a.salesOrgCode, 'nameEn': a.salesOrgName},
              'distributionChannel': {
                'code': a.channelCode,
                'nameEn': a.channelName,
              },
              'division': a.division,
              'paymentTerms': {
                'code': a.paymentTermsCode,
                'nameEn': a.paymentTermsName,
              },
              'creditLimit': a.creditLimit,
              'creditLimitDate': a.creditLimitDate?.toIso8601String(),
              'creditTermDays': a.creditTermDays,
            },
        ]);

  /// A stored value the app cannot read is treated as never stored.
  static List<DepotSalesArea>? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return listFrom(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  /// SAP's `yyyyMMdd`, or ISO-8601 from the local copy. `00000000` — SAP's
  /// "never dated" — and anything unreadable are null, never a made-up date.
  static DateTime? _sapDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    if (RegExp(r'^\d{8}$').hasMatch(raw)) {
      if (raw == '00000000') return null;
      final y = int.parse(raw.substring(0, 4));
      final m = int.parse(raw.substring(4, 6));
      final d = int.parse(raw.substring(6, 8));
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      return DateTime.utc(y, m, d);
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// A number, or a numeric string; anything else is null.
  static double? _number(Object? raw) => switch (raw) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()),
        _ => null,
      };

  static DataMap _map(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : const {};

  static String? _text(Object? raw) {
    final text = raw?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
