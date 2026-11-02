import 'package:steelforce/features/depots/data/models/depot_model.dart';

/// The shape of a batch about to be stored — counts only, never an id, code
/// or name. 207 rows with one distinct id collapse into a single stored row,
/// which nothing downstream can tell from a successful sync.
Map<String, Object> depotBatchShape(List<DepotModel> rows) {
  final ids = [for (final r in rows) r.id];
  return {
    'rows': rows.length,
    'distinctIds': ids.toSet().length,
    'emptyIds': ids.where((id) => id.trim().isEmpty).length,
  };
}
