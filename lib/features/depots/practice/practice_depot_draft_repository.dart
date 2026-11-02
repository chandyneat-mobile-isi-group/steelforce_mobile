import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_suppliers.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_reference_lists.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_draft_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';

/// [DepotDraftRepository] for a practice run.
///
/// * **Create** files the shop in the practice store — awaiting approval, no
///   SAP number — with no network call, so it heads the practice depot list.
/// * **Evidence** is accepted and dropped: nothing leaves the device.
/// * **Pick lists** come from the real repository — read-only lookups, so the
///   dropdowns match the real form.
///
/// Forwards everything to [_real] once [PracticeWorld.isClosed].
class PracticeDepotDraftRepository implements DepotDraftRepository {
  PracticeDepotDraftRepository({
    required DepotDraftRepository real,
    required PracticeWorld world,
    required PracticeDepotStore store,
  })  : _real = real,
        _world = world,
        _store = store;

  final DepotDraftRepository _real;
  final PracticeWorld _world;
  final PracticeDepotStore _store;

  bool get _live => !_world.isClosed;

  @override
  ResultFuture<SavedDepotDraft> createDraft(NewDepotDraft draft) async {
    if (!_live) return _real.createDraft(draft);
    _store.file((sequence, at) => _depotFrom(draft, sequence, at));
    return Success(SavedDepotDraft(
      id: draft.id,
      version: 1,
      status: 'PendingApproval',
      nameEn: draft.nameEn.trim(),
      canEdit: true,
      createdAt: _store.now(),
    ));
  }

  @override
  ResultFuture<DepotReferenceLists> loadReferences({bool refresh = false}) =>
      _real.loadReferences(refresh: refresh);

  @override
  ResultFuture<List<SupplierOption>> loadSupplierOptions(
          DepotSupplierType type) =>
      _real.loadSupplierOptions(type);

  @override
  ResultFuture<DepotDraftAttachment> uploadEvidence(
    String draftId,
    EvidenceUpload upload, {
    MobileDepotKind kind = MobileDepotKind.depot,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!_live) {
      return _real.uploadEvidence(draftId, upload,
          kind: kind, onProgress: onProgress);
    }
    onProgress?.call(1, 1);
    final at = _store.now();
    return Success(DepotDraftAttachment(
      id: upload.id,
      kind: DepotAttachmentKind.evidence,
      category: upload.category,
      note: upload.note,
      originalFileName: upload.fileName,
      contentType: 'image/webp',
      fileSize: 0,
      // Never opened during a lesson; a local placeholder, not a real link.
      url: 'about:blank',
      urlExpiresAt: at.add(const Duration(hours: 1)),
    ));
  }

  @override
  ResultFuture<DepotDraftAttachments> loadAttachments(String draftId) async {
    if (!_live) return _real.loadAttachments(draftId);
    return const Success(DepotDraftAttachments());
  }

  static Depot _depotFrom(NewDepotDraft draft, int sequence, DateTime at) {
    final nameEn = draft.nameEn.trim();
    final nameKh = draft.nameKh?.trim() ?? '';
    final contact = draft.contacts.firstOrNull;
    final area = draft.salesAreas.firstOrNull;
    return Depot(
      id: '${PracticeIds.createdDepotPrefix}$sequence',
      depotCode: 'PRACTICE-NEW-$sequence',
      shopName: nameEn.isNotEmpty ? nameEn : nameKh,
      enName: nameEn.isEmpty ? null : nameEn,
      khName: nameKh.isEmpty ? null : nameKh,
      ownerName: contact?.nameEn ?? contact?.nameKh ?? '',
      phone: draft.mobilePhone ?? draft.telephone,
      address: draft.address.street ?? '',
      province: 'Phnom Penh',
      district: 'Chamkar Mon',
      territory: 'Phnom Penh',
      latitude: draft.location?.latitude ?? 0,
      longitude: draft.location?.longitude ?? 0,
      creditLimit: 0,
      status: DepotStatus.pendingApproval,
      assignedRepId: '',
      assignedRepName: '',
      updatedAt: at,
      createdAt: at,
      salesOrg: area?.salesOrg,
      division: area?.division,
      distributionChannel: area?.distributionChannel,
      depotGroup: area?.customerGroup,
      currency: 'USD',
    );
  }
}
