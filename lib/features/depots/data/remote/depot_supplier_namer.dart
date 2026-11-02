import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';

/// Adds a `name` to each `profile.suppliers` slot of a depot detail answer.
///
/// The server sends a supplier as `{type, code}` only; the rep reads it by
/// name. Names come from the supplier lists (`/profile-lists/{branch|
/// factory}`), fetched once per type per call. Best effort: a list that
/// cannot be fetched leaves its slots as sent.
class DepotSupplierNamer {
  const DepotSupplierNamer(this._options);

  final Future<List<SupplierOption>> Function(DepotSupplierType type) _options;

  static const _slots = ['primary', 'secondary', 'tertiary'];

  /// [depot] with its suppliers named; [depot] itself when there is nothing
  /// to name.
  Future<DataMap> name(DataMap depot) async {
    final profile = depot['profile'];
    final suppliers = profile is Map ? profile['suppliers'] : null;
    if (suppliers is! Map) return depot;

    final lists = <DepotSupplierType, Map<String, String>>{};
    final named = {...suppliers.cast<String, dynamic>()};
    for (final slot in _slots) {
      final supplier = named[slot];
      if (supplier is! Map || supplier['name'] != null) continue;
      final type = DepotSupplierType.fromApi(supplier['type']);
      final code = '${supplier['code'] ?? ''}'.trim();
      if (type == null || code.isEmpty) continue;
      final names = lists[type] ??= await _namesOf(type);
      if (names[code] case final name?) {
        named[slot] = {...supplier.cast<String, dynamic>(), 'name': name};
      }
    }
    return {
      ...depot,
      'profile': {...profile as Map, 'suppliers': named},
    };
  }

  Future<Map<String, String>> _namesOf(DepotSupplierType type) async {
    try {
      return {
        for (final option in await _options(type))
          if (option.nameEn.trim().isNotEmpty) option.code: option.nameEn,
      };
    } on Object {
      return const {};
    }
  }
}
