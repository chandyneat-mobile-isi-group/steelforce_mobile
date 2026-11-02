import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_api_mapper.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';

/// Reads the `GET /mobile/depots` list envelope in each contract it has had.
extension DepotListEnvelope on ApiEnvelope {
  /// The grouped answer: `data.depots`, `data.nonDepots` and `data.draft`
  /// (`depots` + `nonDepots` awaiting approval), every row at once.
  bool get isGroupedDepotList =>
      metadata == null &&
      (data.containsKey('nonDepots') || data.containsKey('draft'));

  /// The rows, each with the `depotType` of the list it was found in
  /// ([DepotTypes]). Older answers: `data.items`, then `data.customers`.
  List<DataMap> get depotRows {
    if (isGroupedDepotList) {
      final draft = object('draft') ?? const <String, dynamic>{};
      return [
        ..._typed(list('depots'), DepotTypes.depot),
        ..._typed(list('nonDepots'), DepotTypes.nonDepot),
        ..._typed(_rows(draft['depots']), DepotTypes.draft),
        // Sent as `NonDepot`; stored apart so it lists with the drafts.
        ..._typed(_rows(draft['nonDepots']), DepotTypes.nonDepotDraft),
      ];
    }
    if (data.containsKey('items')) return list('items');
    // The documented contract before `items`: `data.depots`, paged.
    if (data.containsKey('depots')) return list('depots');
    return list('customers');
  }

  /// Every id in a grouped answer — the rep's whole book — so rows that left
  /// it (a draft approved since) can be dropped. Null for any paged answer.
  Set<String>? completeIds(Iterable<DepotModel> rows) => isGroupedDepotList
      ? {
          for (final r in rows)
            if (r.id.isNotEmpty) r.id
        }
      : null;

  /// The `items` contract pages inside `data` (`page`, `totalPages`) with no
  /// `metadata` block. Counted against the page *asked for*, not the one
  /// echoed back, so a server that ignores the page parameter still ends the
  /// run after `totalPages` requests instead of spinning on page 1. The
  /// grouped answer has no pages.
  bool hasMoreDepots(int page, List<Object> rows) {
    final meta = metadata;
    if (meta != null) return meta.hasNextPage;
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
    return rows.isNotEmpty && page < totalPages;
  }

  /// [type] wins over the row's own `depotType`: the group is what decides
  /// the list.
  static List<DataMap> _typed(List<DataMap> rows, String type) => [
        for (final row in rows) {...row, 'depotType': type}
      ];

  static List<DataMap> _rows(Object? raw) => raw is List
      ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];
}

/// [rows] with an id, mapped. One without would overwrite every other such
/// row under the same empty primary key, so it is left out — the caller
/// counts what is missing.
List<DepotModel> identifiableDepots(List<DataMap> rows) => [
      for (final row in rows)
        if (DepotApiMapper.idOf(row) != null) DepotApiMapper.fromSummary(row),
    ];
