import 'dart:convert';

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_profile.dart';

/// Reads and writes `salesEmployees` and `profile` in the server's own shape.
///
/// The same shape is what the local `sales_employees_json` / `profile_json`
/// columns hold, so one parser serves the wire and the database.
abstract final class DepotProfileModel {
  /// Null when the payload has no `salesEmployees` key — "not sent", which
  /// must not wipe a list stored from an earlier answer.
  static List<DepotSalesEmployee>? salesEmployeesFrom(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final e in raw.whereType<Map>())
        DepotSalesEmployee(
          employeeCode: _text(e['employeeCode']),
          employeeName: _text(e['employeeName']),
          territoryCode: _text(e['territoryCode']),
          territoryName: _text(e['territoryName']),
          branchCode: _text(e['branchCode']),
          branchName: _text(e['branchName']),
          regionCode: _text(e['regionCode']),
          regionName: _text(e['regionName']),
        ),
    ];
  }

  /// Null when the payload has no `profile` object.
  static DepotProfile? profileFrom(Object? raw) {
    if (raw is! Map) return null;
    final facts = _map(raw['fieldFacts']);
    final suppliers = _map(raw['suppliers']);
    final management = _map(raw['management']);
    return DepotProfile(
      telegram: _text(facts['telegram']),
      outletStatus: _text(facts['outletStatus']),
      houseNumber: _text(facts['houseNumber']),
      addressLine: _text(facts['addressLine']),
      primarySupplier: _supplier(suppliers['primary']),
      secondarySupplier: _supplier(suppliers['secondary']),
      tertiarySupplier: _supplier(suppliers['tertiary']),
      primarySupplierCode: _supplierCode(suppliers['primary']),
      secondarySupplierCode: _supplierCode(suppliers['secondary']),
      tertiarySupplierCode: _supplierCode(suppliers['tertiary']),
      tier: _text(management['tier']),
      channel: _text(management['channel']),
      subChannel: _text(management['subChannel']),
      outletAction: _text(management['outletAction']),
      keyAccountId: _text(management['keyAccountId']),
      coverageType: _text(management['coverageType']),
      visit: _text(management['visit']),
      territory: _text(management['territory']),
    );
  }

  static String? encodeSalesEmployees(List<DepotSalesEmployee>? list) =>
      list == null
          ? null
          : jsonEncode([
              for (final e in list)
                {
                  'employeeCode': e.employeeCode,
                  'employeeName': e.employeeName,
                  'territoryCode': e.territoryCode,
                  'territoryName': e.territoryName,
                  'branchCode': e.branchCode,
                  'branchName': e.branchName,
                  'regionCode': e.regionCode,
                  'regionName': e.regionName,
                },
            ]);

  static String? encodeProfile(DepotProfile? p) => p == null
      ? null
      : jsonEncode({
          'fieldFacts': {
            'telegram': p.telegram,
            'outletStatus': p.outletStatus,
            'houseNumber': p.houseNumber,
            'addressLine': p.addressLine,
          },
          'suppliers': {
            'primary':
                _storedSupplier(p.primarySupplier, p.primarySupplierCode),
            'secondary':
                _storedSupplier(p.secondarySupplier, p.secondarySupplierCode),
            'tertiary':
                _storedSupplier(p.tertiarySupplier, p.tertiarySupplierCode),
          },
          'management': {
            'tier': p.tier,
            'channel': p.channel,
            'subChannel': p.subChannel,
            'outletAction': p.outletAction,
            'keyAccountId': p.keyAccountId,
            'coverageType': p.coverageType,
            'visit': p.visit,
            'territory': p.territory,
          },
        });

  static List<DepotSalesEmployee>? decodeSalesEmployees(String? json) =>
      salesEmployeesFrom(_decode(json));

  static DepotProfile? decodeProfile(String? json) =>
      profileFrom(_decode(json));

  /// A stored value the app cannot read is treated as never stored.
  static Object? _decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return jsonDecode(json);
    } on FormatException {
      return null;
    }
  }

  static DataMap _map(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : const {};

  /// A supplier as the rep reads it: its name alone when the answer carries
  /// one (see `DepotSupplierNamer`), otherwise what was sent.
  static String? _supplier(Object? raw) => raw is Map
      ? _text(raw['name'] ?? raw['nameEn']) ?? _text(raw)
      : _text(raw);

  static String? _supplierCode(Object? raw) =>
      raw is Map ? _text(raw['code']) : null;

  /// Kept with its code, so a stored supplier still opens; read back by
  /// [_supplier] and [_supplierCode].
  static Object? _storedSupplier(String? name, String? code) =>
      code == null ? name : {'name': name, 'code': code};

  /// Display text for any JSON value; blank and null are both null. An
  /// object (e.g. a supplier `{type, code}`) is its non-null values joined.
  static String? _text(Object? raw) {
    final text = switch (raw) {
      null => null,
      String s => s,
      num() || bool() => '$raw',
      Map m =>
        m.values.where((v) => v != null && '$v'.trim().isNotEmpty).join(' · '),
      List l => l.where((v) => v != null).join(', '),
      _ => '$raw',
    };
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
