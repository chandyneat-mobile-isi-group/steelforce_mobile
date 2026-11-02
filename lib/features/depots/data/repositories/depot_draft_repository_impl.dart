import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/repositories/depot_draft_failure_mapper.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';

class DepotDraftRepositoryImpl implements DepotDraftRepository {
  DepotDraftRepositoryImpl({
    required DepotDraftRemoteDataSource remote,
    required NetworkInfo network,
  })  : _remote = remote,
        _network = network;

  final DepotDraftRemoteDataSource _remote;
  final NetworkInfo _network;

  /// The lists are the same for every user and hold no PII, so one copy per
  /// app session is enough. A load in flight is shared, so two widgets asking
  /// at once cause one request.
  DepotReferenceLists? _references;
  Future<Result<DepotReferenceLists>>? _referencesInFlight;

  @override
  ResultFuture<SavedDepotDraft> createDraft(NewDepotDraft draft) =>
      _guard(() => _remote.createDraft(draft));

  @override
  ResultFuture<DepotReferenceLists> loadReferences({bool refresh = false}) {
    final cached = _references;
    if (!refresh && cached != null) return Future.value(Success(cached));
    return _referencesInFlight ??= _guard(_remote.fetchReferences).then((r) {
      _referencesInFlight = null;
      // Lists that are not synced yet are not cached: the next open retries.
      if (r case Success(:final data) when data.canCompleteSalesArea) {
        _references = data;
      }
      return r;
    });
  }

  @override
  ResultFuture<List<SupplierOption>> loadSupplierOptions(
          DepotSupplierType type) =>
      _guard(() => _remote.fetchSupplierOptions(type));

  @override
  ResultFuture<DepotDraftAttachment> uploadEvidence(
    String draftId,
    EvidenceUpload upload, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int sent, int total)? onProgress,
  }) =>
      _guard(() => _remote.uploadEvidence(draftId, upload,
          kind: kind, onProgress: onProgress));

  @override
  ResultFuture<DepotDraftAttachments> loadAttachments(String draftId) =>
      _guard(() => _remote.fetchAttachments(draftId));

  ResultFuture<T> _guard<T>(Future<T> Function() request) async {
    // Real reachability (ADR-005): failing here is faster and more honest
    // than waiting out a socket timeout.
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      return Success(await request());
    } on ApiException catch (e) {
      return Failed(DepotDraftFailureMapper.map(e.error));
    } on ServerException {
      return const Failed(
          ServerFailure(message: 'depots.draft.error.unreadable'));
    }
  }
}
