import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';

class DepotRegistrationQueueState extends Equatable {
  const DepotRegistrationQueueState({
    this.items = const [],
    this.loaded = false,
    this.syncing = false,
    this.messageKey,
    this.messageSeq = 0,
  });

  final List<PendingDepotRegistration> items;
  final bool loaded;

  /// The rep's **Sync** is running — the drain it started has not finished.
  final bool syncing;

  /// A localization key for a one-off outcome of a rep action (a reopen that
  /// succeeded, or one that was refused). Cleared on the next emit.
  final String? messageKey;

  /// Bumped with every message, so the same message twice in a row is still
  /// a new state and the snackbar shows again.
  final int messageSeq;

  int get outstanding => items.length;
  int get needingRep => items.where((i) => i.status.needsRep).length;
  int get sending => outstanding - needingRep;

  DepotRegistrationQueueState copyWith({
    List<PendingDepotRegistration>? items,
    bool? loaded,
    bool? syncing,
    String? messageKey,
  }) =>
      DepotRegistrationQueueState(
        items: items ?? this.items,
        loaded: loaded ?? this.loaded,
        syncing: syncing ?? this.syncing,
        messageKey: messageKey,
        messageSeq: messageKey == null ? messageSeq : messageSeq + 1,
      );

  @override
  List<Object?> get props => [items, loaded, syncing, messageKey, messageSeq];
}

/// The Sync Center's view of depot registrations waiting in the outbox, and
/// the rep's actions on the ones that need them.
///
/// Sending is automatic (the sync engine drains the outbox); this cubit only
/// mirrors the queue and exposes **Retry** (after checking the depot list),
/// **Fix** (reopen a SAP refusal in the wizard) and **Discard**.
class DepotRegistrationQueueCubit extends Cubit<DepotRegistrationQueueState> {
  DepotRegistrationQueueCubit({
    required DepotRegistrationOutbox outbox,
    required Future<bool> Function() syncNow,
  })  : _outbox = outbox,
        _syncNow = syncNow,
        super(const DepotRegistrationQueueState()) {
    _sub = _outbox.watchAll().listen(
      (items) {
        if (!isClosed) emit(state.copyWith(items: items, loaded: true));
      },
      // A failed read leaves the last list on screen rather than an unhandled
      // stream error; the next queue change re-emits.
      onError: (Object _) {},
    );
  }

  final DepotRegistrationOutbox _outbox;
  final Future<bool> Function() _syncNow;
  late final StreamSubscription<List<PendingDepotRegistration>> _sub;

  /// The rep's "Sync now": skips any backoff and drains at once. Says so when
  /// the server cannot be reached, rather than appearing to do nothing.
  ///
  /// The drain sends everything waiting, not only depots — a registration is
  /// what later visits and quotations for that shop hang off, and the engine
  /// keeps that order.
  Future<void> syncNow() async {
    if (state.syncing) return;
    emit(state.copyWith(syncing: true));
    var ran = true;
    try {
      await _outbox.expedite();
      ran = await _syncNow();
    } finally {
      if (!isClosed) {
        emit(state.copyWith(
          syncing: false,
          messageKey: ran ? null : 'sync_center.depot.sync_offline',
        ));
      }
    }
  }

  /// For a row whose outcome was unknown: the rep has checked the depot list
  /// and the shop is not on it.
  Future<void> retry(String id) async {
    await _outbox.retry(id);
  }

  Future<void> discard(String id) async {
    await _outbox.discard(id);
  }

  Future<void> reopen(String id) async {
    final result = await _outbox.reopenAsDraft(id);
    if (isClosed) return;
    emit(
      state.copyWith(
        messageKey: result.when(
          success: (_) => 'sync_center.depot.reopened',
          failure: (f) => f.message.startsWith('sync_center.')
              ? f.message
              : 'sync_center.depot.reopen_failed',
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
