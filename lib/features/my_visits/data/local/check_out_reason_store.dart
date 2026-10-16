import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/visit_check_models.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';

/// The last "no order" reason list the server sent, so a rep can check out
/// without an order while offline. Non-sensitive reference data, so the plain
/// Hive cache box (`security.md` §2).
class CheckOutReasonStore {
  const CheckOutReasonStore(this._box);
  final Box<dynamic> _box;

  static const _key = 'visits.check_out_reasons.v1';

  List<NoOrderReason> read() {
    final raw = _box.get(_key);
    if (raw is! String) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((m) => noOrderReasonFromJson(m.cast<String, dynamic>()))
          .whereType<NoOrderReason>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<NoOrderReason> reasons) => _box.put(
        _key,
        jsonEncode(<DataMap>[for (final r in reasons) noOrderReasonToJson(r)]),
      );
}
