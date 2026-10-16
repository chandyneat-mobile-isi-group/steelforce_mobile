import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity_type.dart';
import 'package:steelforce/features/depots/domain/usecases/add_depot_activity.dart';
import 'package:steelforce/features/depots/domain/usecases/add_depot_note.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_depot_activities.dart';
import 'package:steelforce/features/depots/domain/usecases/fetch_depot_notes.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_by_id.dart';
import 'package:steelforce/features/depots/domain/usecases/hydrate_depot.dart';
import 'package:steelforce/features/depots/domain/usecases/record_depot_viewed.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_detail_state.dart';

class DepotDetailCubit extends Cubit<DepotDetailState> {
  DepotDetailCubit({
    required GetDepotById getDepotById,
    required HydrateDepot hydrateDepot,
    required FetchDepotNotes fetchDepotNotes,
    required AddDepotNote addDepotNote,
    required FetchDepotActivities fetchDepotActivities,
    required AddDepotActivity addDepotActivity,
    required RecordDepotViewed recordDepotViewed,
  })  : _getDepotById = getDepotById,
        _hydrateDepot = hydrateDepot,
        _fetchDepotNotes = fetchDepotNotes,
        _addDepotNote = addDepotNote,
        _fetchDepotActivities = fetchDepotActivities,
        _addDepotActivity = addDepotActivity,
        _recordDepotViewed = recordDepotViewed,
        super(const DepotDetailLoading());

  final GetDepotById _getDepotById;
  final HydrateDepot _hydrateDepot;
  final FetchDepotNotes _fetchDepotNotes;
  final AddDepotNote _addDepotNote;
  final FetchDepotActivities _fetchDepotActivities;
  final AddDepotActivity _addDepotActivity;
  final RecordDepotViewed _recordDepotViewed;

  Future<void> load(String depotId) async {
    emit(const DepotDetailLoading());
    unawaited(_recordDepotViewed(DepotIdParams(depotId)));

    // Online-first: refresh this depot from the API before reading it, so the
    // screen shows the server's record rather than the last synced copy. The
    // list pull carries only a summary, so this is also what fills in the
    // address, contacts and SAP block. Failure and offline are ignored — the
    // local copy below is the fallback — and the wait is capped so a slow
    // connection cannot hold the screen.
    // Discarded to `void` *before* the timeout: `Future.timeout` checks its
    // fallback against the future's runtime type, which can be narrower than
    // `Result<void>` (a `Future<Failed<void>>`), and would throw.
    await _hydrateDepot(DepotIdParams(depotId))
        .then<void>((_) {})
        .timeout(ApiDefaults.onlineFirstWait, onTimeout: () {});

    final depotResult = await _getDepotById(DepotIdParams(depotId));
    await depotResult.when(
      success: (depot) async {
        final notesResult = await _fetchDepotNotes(DepotIdParams(depotId));
        final activitiesResult =
            await _fetchDepotActivities(DepotIdParams(depotId));
        emit(DepotDetailLoaded(
          depot: depot,
          notes: notesResult.when(success: (n) => n, failure: (_) => const []),
          activities: activitiesResult.when(
              success: (a) => a, failure: (_) => const []),
        ));
      },
      failure: (f) async => emit(DepotDetailError(f.message)),
    );
  }

  Future<void> addNote(String body) async {
    final current = state;
    if (current is! DepotDetailLoaded || body.trim().isEmpty) return;

    emit(current.copyWith(isAddingNote: true));
    final result = await _addDepotNote(
      AddDepotNoteParams(depotId: current.depot.id, body: body.trim()),
    );
    await result.when(
      success: (_) async {
        await _addDepotActivity(AddDepotActivityParams(DepotActivity(
          id: '${current.depot.id}-ACT-${DateTime.now().microsecondsSinceEpoch}',
          depotId: current.depot.id,
          type: DepotActivityType.note,
          summary: body.trim(),
          createdAt: DateTime.now(),
        )));
        final notesResult =
            await _fetchDepotNotes(DepotIdParams(current.depot.id));
        final activitiesResult =
            await _fetchDepotActivities(DepotIdParams(current.depot.id));
        emit(current.copyWith(
          notes: notesResult.when(
              success: (n) => n, failure: (_) => current.notes),
          activities: activitiesResult.when(
              success: (a) => a, failure: (_) => current.activities),
          isAddingNote: false,
        ));
      },
      failure: (_) async => emit(current.copyWith(isAddingNote: false)),
    );
  }

  Future<void> logActivity(DepotActivityType type, String summary) async {
    final current = state;
    if (current is! DepotDetailLoaded) return;

    await _addDepotActivity(AddDepotActivityParams(DepotActivity(
      id: '${current.depot.id}-ACT-${DateTime.now().microsecondsSinceEpoch}',
      depotId: current.depot.id,
      type: type,
      summary: summary,
      createdAt: DateTime.now(),
    )));
    final activitiesResult =
        await _fetchDepotActivities(DepotIdParams(current.depot.id));
    emit(current.copyWith(
        activities: activitiesResult.when(
            success: (a) => a, failure: (_) => current.activities)));
  }

  /// Updates the depot details optimistically and appends an audit activity.
  Future<void> updateDepot(Depot updated) async {
    final current = state;
    if (current is! DepotDetailLoaded) return;

    emit(current.copyWith(depot: updated));

    await logActivity(
      DepotActivityType.note,
      'Depot details updated: ${updated.shopName}',
    );
  }
}
