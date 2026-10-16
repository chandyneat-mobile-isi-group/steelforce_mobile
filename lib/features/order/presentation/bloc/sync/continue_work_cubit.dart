import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/delete_quotation.dart';
import 'package:steelforce/features/order/domain/usecases/get_editable_remote_drafts.dart';
import 'package:steelforce/features/order/domain/usecases/watch_quotations.dart';

class ContinueWorkState extends Equatable {
  const ContinueWorkState({
    this.drafts = const [],
    this.returnReasons = const {},
    this.remoteDrafts = const [],
    this.loaded = false,
  });

  /// Resumable quotations saved on this device, most-recently-edited first —
  /// including ones an administrator sent back.
  final List<Quotation> drafts;

  /// Local quotation id → the administrator's reason, for each of [drafts]
  /// that was returned from review. Present (possibly with a null reason)
  /// only for returned ones.
  final Map<String, String?> returnReasons;

  /// Editable documents on the backend with no copy on this device — opened
  /// on another device, or online without being saved here.
  final List<QuotationSummary> remoteDrafts;
  final bool loaded;

  int get totalCount => drafts.length + remoteDrafts.length;

  Quotation? get mostRecent => drafts.isEmpty ? null : drafts.first;
  bool get hasMultiple => totalCount > 1;

  bool isReturned(String quotationId) => returnReasons.containsKey(quotationId);

  ContinueWorkState copyWith({
    List<Quotation>? drafts,
    Map<String, String?>? returnReasons,
    List<QuotationSummary>? remoteDrafts,
    bool? loaded,
  }) =>
      ContinueWorkState(
        drafts: drafts ?? this.drafts,
        returnReasons: returnReasons ?? this.returnReasons,
        remoteDrafts: remoteDrafts ?? this.remoteDrafts,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [drafts, returnReasons, remoteDrafts, loaded];
}

/// Feeds the floating "Continue Previous Work" card from live data:
///
/// * saved quotations not yet handed to the sync queue;
/// * quotations an administrator **returned** from review — the rep's turn
///   again, with the reason shown;
/// * editable documents on the Admin backend this device has no copy of.
///
/// The backend half refreshes after every sync run, so a return decided in the
/// portal reaches the card without the rep doing anything. Purely surfaces
/// state; it never auto-navigates or discards.
class ContinueWorkCubit extends Cubit<ContinueWorkState> {
  ContinueWorkCubit({
    required WatchQuotations watchQuotations,
    required SyncQueueRepository syncQueue,
    required DeleteQuotation deleteQuotation,
    required GetEditableRemoteDrafts getRemoteDrafts,
    required Stream<bool> syncRunning,
    this.remoteRefreshInterval = const Duration(minutes: 2),
  })  : _syncQueue = syncQueue,
        _deleteQuotation = deleteQuotation,
        _getRemoteDrafts = getRemoteDrafts,
        super(const ContinueWorkState()) {
    _quotationsSub = watchQuotations(const NoParams()).listen(_onQuotations);
    _queueSub = syncQueue.watchQueue().listen(_onQueue);
    // A sync run finishing is exactly when the backend may know something new.
    _syncSub = syncRunning.where((running) => !running).listen((_) {
      unawaited(refreshRemote());
    });
    unawaited(refreshRemote(force: true));
  }

  final SyncQueueRepository _syncQueue;
  final DeleteQuotation _deleteQuotation;
  final GetEditableRemoteDrafts _getRemoteDrafts;

  /// Floor between backend reads, so a burst of sync runs costs one call.
  final Duration remoteRefreshInterval;

  late final StreamSubscription<List<Quotation>> _quotationsSub;
  late final StreamSubscription<List<SyncQueueItem>> _queueSub;
  late final StreamSubscription<bool> _syncSub;

  List<Quotation> _quotations = const [];
  List<SyncQueueItem> _queue = const [];
  List<QuotationSummary> _remote = const [];
  DateTime? _lastRemoteRead;

  /// Permanently discards a local draft (deletes the quotation and any queue
  /// entry). The backend document, if any, is left for the portal to expire.
  Future<void> discard(String quotationId) async {
    await _deleteQuotation(QuotationIdParams(quotationId));
    await _syncQueue.remove(quotationId);
  }

  /// Re-reads the rep's editable backend documents. Offline or failing, the
  /// last good list stays.
  Future<void> refreshRemote({bool force = false}) async {
    final last = _lastRemoteRead;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < remoteRefreshInterval) {
      return;
    }
    _lastRemoteRead = DateTime.now();
    final result = await _getRemoteDrafts(const NoParams());
    if (isClosed) return;
    result.when(
      success: (rows) {
        _remote = rows;
        _recompute();
      },
      failure: (_) {},
    );
  }

  void _onQuotations(List<Quotation> quotations) {
    _quotations = quotations;
    _recompute();
  }

  void _onQueue(List<SyncQueueItem> items) {
    _queue = items;
    _recompute();
  }

  void _recompute() {
    if (isClosed) return;
    final byQuotation = {for (final i in _queue) i.quotationId: i};
    final returnReasons = <String, String?>{};

    final drafts = _quotations.where((q) {
      if (q.status != QuotationStatus.saved) return false;
      final queued = byQuotation[q.id];
      if (queued == null) return true;
      if (queued.status == QuotationSyncStatus.returned) {
        returnReasons[q.id] = queued.decisionReason;
        return true;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // A backend document already linked to a local quotation is that
    // quotation — listing it twice would offer two ways to edit one document.
    final linked = {
      for (final q in _quotations)
        if (q.remoteId != null) q.remoteId!,
      for (final i in _queue)
        if (i.remoteQuotationId != null) i.remoteQuotationId!,
    };
    // Empty documents are the builder's: it opens a server draft every time it
    // starts online, and one the rep walked away from is not work to continue.
    final remoteDrafts = _remote
        .where((r) => !linked.contains(r.id) && r.lineCount > 0)
        .toList();

    emit(ContinueWorkState(
      drafts: drafts,
      returnReasons: returnReasons,
      remoteDrafts: remoteDrafts,
      loaded: true,
    ));
  }

  @override
  Future<void> close() async {
    await _quotationsSub.cancel();
    await _queueSub.cancel();
    await _syncSub.cancel();
    return super.close();
  }
}
