import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';

/// Bundles every locally-pending visit-capture row into one push request —
/// the outbound mirror of [RouteSyncPage] (the pull-sync page DTO).
class VisitPushBatch {
  const VisitPushBatch({
    required this.checkIns,
    required this.checkOuts,
    required this.orderLines,
    required this.stockUpdates,
    required this.returns,
    required this.collections,
    required this.notes,
    required this.photos,
  });

  final List<CheckInRecordModel> checkIns;
  final List<CheckOutRecordModel> checkOuts;
  final List<VisitOrderLineModel> orderLines;
  final List<VisitStockUpdateModel> stockUpdates;
  final List<VisitReturnModel> returns;
  final List<VisitCollectionModel> collections;
  final List<VisitNoteModel> notes;
  final List<VisitPhotoModel> photos;

  bool get isEmpty =>
      checkIns.isEmpty &&
      checkOuts.isEmpty &&
      orderLines.isEmpty &&
      stockUpdates.isEmpty &&
      returns.isEmpty &&
      collections.isEmpty &&
      notes.isEmpty &&
      photos.isEmpty;

  int get rowCount =>
      checkIns.length +
      checkOuts.length +
      orderLines.length +
      stockUpdates.length +
      returns.length +
      collections.length +
      notes.length +
      photos.length;

  /// All row ids across every list, grouped by their source table — used to
  /// mark accepted rows synced after a successful push.
  Map<String, List<String>> idsByTable() => {
        'checkins': [for (final r in checkIns) r.id],
        'checkouts': [for (final r in checkOuts) r.id],
        'visit_orders': [for (final r in orderLines) r.id],
        'visit_stock_updates': [for (final r in stockUpdates) r.id],
        'visit_returns': [for (final r in returns) r.id],
        'visit_collections': [for (final r in collections) r.id],
        'visit_notes': [for (final r in notes) r.id],
        'visit_photos': [for (final r in photos) r.id],
      };
}
