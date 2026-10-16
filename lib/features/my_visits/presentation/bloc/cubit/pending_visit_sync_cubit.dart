import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/discard_pending_visit_stop.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';

class PendingVisitSyncState extends Equatable {
  const PendingVisitSyncState({
    this.pending = const PendingVisitSync(),
    this.loaded = false,
    this.syncing = false,
    this.discarding = const {},
    this.messageKey,
    this.messageSeq = 0,
  });

  final PendingVisitSync pending;

  /// False until the first read lands, so the Sync Center does not flash
  /// "everything is synced" while it is still reading.
  final bool loaded;

  /// A send is in progress — the rep's own tap or an automatic drain.
  final bool syncing;

  /// Stops whose discard is in progress, so their actions can be disabled.
  final Set<String> discarding;

  /// A localization key for a one-off outcome of a rep action. Cleared on the
  /// next emit.
  final String? messageKey;

  /// Bumped with every message, so the same message twice is a new state.
  final int messageSeq;

  PendingVisitStop? stop(String stopId) {
    for (final s in pending.stops) {
      if (s.stopId == stopId) return s;
    }
    return null;
  }

  PendingVisitSyncState copyWith({
    PendingVisitSync? pending,
    bool? loaded,
    bool? syncing,
    Set<String>? discarding,
    String? messageKey,
  }) =>
      PendingVisitSyncState(
        pending: pending ?? this.pending,
        loaded: loaded ?? this.loaded,
        syncing: syncing ?? this.syncing,
        discarding: discarding ?? this.discarding,
        messageKey: messageKey,
        messageSeq: messageKey == null ? messageSeq : messageSeq + 1,
      );

  @override
  List<Object?> get props =>
      [pending, loaded, syncing, discarding, messageKey, messageSeq];
}

/// Visit work still on the device, for the Sync Center, and the rep's two
/// actions on it: **Sync** and **Discard**.
///
/// Reloads whenever a sync run finishes ([syncRunning] turns false), so a
/// stop leaves the list as soon as its rows reach the server.
class PendingVisitSyncCubit extends Cubit<PendingVisitSyncState> {
  PendingVisitSyncCubit({
    required GetPendingVisitSync getPendingVisitSync,
    DiscardPendingVisitStop? discardPendingVisitStop,
    Stream<bool>? syncRunning,
    bool syncRunningNow = false,
    Future<bool> Function()? syncNow,
    void Function()? onStopDiscarded,
  })  : _get = getPendingVisitSync,
        _discard = discardPendingVisitStop,
        _syncNow = syncNow,
        _onStopDiscarded = onStopDiscarded,
        _engineRunning = syncRunningNow,
        super(PendingVisitSyncState(syncing: syncRunningNow)) {
    _sub = syncRunning?.listen((running) {
      _engineRunning = running;
      _emitSyncing();
      if (!running) load();
    });
  }

  final GetPendingVisitSync _get;
  final DiscardPendingVisitStop? _discard;

  /// Sends everything waiting, in the engine's order: depot registrations,
  /// check-ins, quotations and orders, then check-outs and captures. The
  /// same drain the Sync Center's **Sync Now** runs. Answers false when it
  /// could not run (offline, or signed out).
  final Future<bool> Function()? _syncNow;

  /// Lets whatever else shows the stop (the resume card) re-read it.
  final void Function()? _onStopDiscarded;

  StreamSubscription<bool>? _sub;
  bool _engineRunning;
  bool _requested = false;

  /// Whether this cubit can send at all — the Sync button hides otherwise.
  bool get canSync => _syncNow != null;

  /// Whether this cubit can discard at all — the Discard button hides
  /// otherwise.
  bool get canDiscard => _discard != null;

  Future<void> load() async {
    final result = await _get(const NoParams());
    if (isClosed) return;
    result.when(
      success: (pending) =>
          emit(state.copyWith(pending: pending, loaded: true)),
      // A device read failing leaves the last known list; the section is a
      // preview, and the sign-out guard reads the counts separately.
      failure: (_) => emit(state.copyWith(loaded: true)),
    );
  }

  /// The rep's **Sync** on a visit: sends everything waiting, not just this
  /// stop — a stop's check-out may not overtake its check-in, nor its
  /// orders, so there is no safe per-stop send.
  Future<void> syncNow() async {
    final send = _syncNow;
    if (send == null || state.syncing) return;
    _requested = true;
    _emitSyncing();
    var ran = false;
    try {
      ran = await send();
    } catch (_) {
      // The engine persists its own progress; a throw only ends this run.
      ran = true;
    } finally {
      _requested = false;
    }
    if (isClosed) return;
    if (!ran) {
      emit(state.copyWith(
        syncing: _engineRunning,
        messageKey: 'sync_center.visit.sync_offline',
      ));
    } else {
      _emitSyncing();
    }
    await load();
  }

  /// The rep's **Discard** on a visit: throws away everything at [stopId]
  /// the server does not have yet and puts the stop back so the visit can be
  /// done again. The caller has already asked the rep to confirm.
  Future<void> discard(String stopId) async {
    final discard = _discard;
    if (discard == null || state.discarding.contains(stopId)) return;
    emit(state.copyWith(discarding: {...state.discarding, stopId}));
    final result = await discard(StopIdParams(stopId));
    if (isClosed) return;
    final ok = result.when(success: (_) => true, failure: (_) => false);
    if (ok) _onStopDiscarded?.call();
    emit(state.copyWith(
      discarding: {...state.discarding}..remove(stopId),
      messageKey: ok
          ? 'sync_center.visit.discarded'
          : 'sync_center.visit.discard_failed',
    ));
    await load();
  }

  void _emitSyncing() {
    if (isClosed) return;
    final syncing = _requested || _engineRunning;
    if (syncing != state.syncing) emit(state.copyWith(syncing: syncing));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
