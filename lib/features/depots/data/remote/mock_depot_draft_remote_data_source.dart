// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/depots/data/remote/depot_draft_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_backend.dart';
import 'package:steelforce/features/depots/data/remote/mock_master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/entities/registration/evidence_file_rules.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';

/// The registration routes (`POST /mobile/depots`, the record's attachments,
/// the pick lists), answered from [MockDepotBackend].
///
/// A sent registration is stored once — a resend under the same id answers the
/// stored record, as the live 200 does — and shows up in the directory as
/// awaiting approval. Evidence is recorded by name and path only: the file is
/// never read, so a browser's `blob:` path works the same as a device path.
class MockDepotDraftRemoteDataSource implements DepotDraftRemoteDataSource {
  const MockDepotDraftRemoteDataSource(this._backend);

  final MockDepotBackend _backend;

  /// How long a demo write takes — long enough for the submit progress to be
  /// seen, short enough not to drag.
  static const Duration _writeLatency = Duration(milliseconds: 600);

  /// The links the live server signs expire; a demo link simply outlives the
  /// session.
  static const Duration _linkLifetime = Duration(days: 1);

  @override
  Future<SavedDepotDraft> createDraft(NewDepotDraft draft) async {
    await Future<void>.delayed(_writeLatency);
    final saved = _backend.saveDraft(draft);
    return SavedDepotDraft(
      id: saved.id,
      version: saved.version,
      status: saved.status,
      nameEn: saved.nameEn,
      kind: saved.kind,
      isNew: saved.isNew,
      createdAt: saved.createdAt,
      attachments: _attachments(saved.id),
    );
  }

  @override
  Future<DepotReferenceLists> fetchReferences() async {
    await MockLatency.tick();
    return DepotReferenceLists(
      salesOrgs: _options(MasterDataType.salesOrg),
      distributionChannels: _options(MasterDataType.distributionChannel),
      customerGroups: _options(MasterDataType.depotGroup),
      salesOffices: _options(MasterDataType.salesOffice),
      shippingConditions: _options(MasterDataType.shippingCondition),
      paymentTerms: _options(MasterDataType.paymentTerm),
    );
  }

  @override
  Future<List<SupplierOption>> fetchSupplierOptions(
    DepotSupplierType type,
  ) async {
    await MockLatency.tick();
    return switch (type) {
      DepotSupplierType.branch => const [
          SupplierOption(code: 'BR-PP', nameEn: 'ISI Phnom Penh Branch'),
          SupplierOption(code: 'BR-SR', nameEn: 'ISI Siem Reap Branch'),
          SupplierOption(code: 'BR-BB', nameEn: 'ISI Battambang Branch'),
        ],
      DepotSupplierType.factory => const [
          SupplierOption(code: 'FC-01', nameEn: 'ISI Steel Factory'),
          SupplierOption(code: 'FC-02', nameEn: 'ISI Roofing Factory'),
        ],
    };
  }

  @override
  Future<DepotDraftAttachment> uploadEvidence(
    String draftId,
    EvidenceUpload upload, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_backend.draft(draftId) == null) {
      throw const ApiException(
          ApiError(code: ApiErrorCodes.depotNotFound, statusCode: 404));
    }
    final media = EvidenceFileRules.mediaTypeFor(upload.fileName);
    if (media == null) {
      throw const ServerException(message: 'Unsupported evidence type.');
    }

    final stored = _backend.attachmentsOf(draftId);
    // A resend of the same id answers the stored file, never a duplicate.
    for (final existing in stored) {
      if (existing.id == upload.id) return existing;
    }

    const steps = 4;
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(_writeLatency ~/ steps);
      onProgress?.call(step, steps);
    }

    final attachment = DepotDraftAttachment(
      id: upload.id,
      kind: DepotAttachmentKind.evidence,
      category: upload.category,
      note: upload.note,
      originalFileName: upload.fileName,
      contentType: media,
      fileSize: 0,
      url: upload.filePath,
      thumbnailUrl: media.startsWith('image/') ? upload.filePath : null,
      urlExpiresAt: _backend.now().add(_linkLifetime),
      takenAt: upload.takenAt,
      canRemove: true,
    );
    stored.add(attachment);
    return attachment;
  }

  @override
  Future<DepotDraftAttachments> fetchAttachments(
    String draftId, {
    MobileDepotKind kind = MobileDepotKind.depot,
  }) async {
    await MockLatency.tick();
    return _attachments(draftId);
  }

  DepotDraftAttachments _attachments(String draftId) =>
      DepotDraftAttachments(evidence: List.of(_backend.attachmentsOf(draftId)));

  static List<ReferenceOption> _options(MasterDataType type) => [
        for (final MasterDataItem item
            in MockMasterDataRemoteDataSource.fixtures[type] ?? const [])
          ReferenceOption(code: item.code, name: item.name),
      ];
}
