// =============================================================================
// depot_repository.dart
//
// Path: lib/features/depot/domain/repositories/depot_repository.dart
//
// Domain-layer contract. The bloc depends ONLY on this — never on Dio, never
// on the local DB. That is what lets you unit-test AddDepotBloc with a fake.
// =============================================================================

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_note.dart';
import 'package:steelforce/features/depots/domain/entities/depot_paged_result.dart';

/// Outcome of a submit attempt.
///
/// `queuedOffline == true` means the record is safely on disk and will sync
/// later — it does NOT mean SAP accepted it. The UI must say so, otherwise a
/// rep writes an order against a depot code that does not exist yet.
class SubmitResult {
  final bool queuedOffline;

  /// Local tracking id. Present in both online and offline cases.
  final String localId;

  /// SAP depot number. Null until HQ approves and SAP assigns it.
  final String? depotCode;

  const SubmitResult({
    required this.localId,
    this.queuedOffline = false,
    this.depotCode,
  });
}

/// Thrown for anything the rep can act on (validation rejected by the
/// middleware, duplicate name, expired session). The bloc surfaces
/// [message] directly.
class DepotSubmitException implements Exception {
  final String message;
  final String? sapField;

  const DepotSubmitException(this.message, {this.sapField});

  @override
  String toString() => message;
}

abstract interface class DepotRepository {
  ResultFuture<DepotPagedResult> browse({
    required int page,
    required int pageSize,
    String query = '',
    DepotFilter filter = const DepotFilter(),
  });

  ResultFuture<Depot> getById(String id);
  ResultFuture<void> toggleFavorite(String depotId);
  ResultFuture<List<Depot>> fetchFavorites();
  ResultFuture<List<Depot>> fetchRecent();
  ResultFuture<void> recordViewed(String depotId);
  ResultFuture<List<DepotNote>> fetchNotes(String depotId);
  ResultFuture<void> addNote(String depotId, String body);
  ResultFuture<List<DepotActivity>> fetchActivities(String depotId);
  ResultFuture<void> addActivity(DepotActivity activity);
}
