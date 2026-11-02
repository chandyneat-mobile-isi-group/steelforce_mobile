// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_fixtures.dart';
import 'package:steelforce/features/depots/data/remote/mock_depot_seed.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/depot_list_kind.dart';
import 'package:steelforce/features/depots/domain/entities/depot_profile.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/domain/entities/registration/depot_draft_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/registration/mobile_depot_kind.dart';
import 'package:steelforce/features/depots/domain/entities/registration/new_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/registration/saved_depot_draft.dart';

/// The demo backend's state for one app session, shared by every mock depot
/// source so a write through one is visible to the others: a registration
/// sent through the draft route appears in the next directory sync as
/// awaiting approval, opens on the detail screen, and has stop information.
///
/// In memory only — a reload or restart resets it, as a fresh demo should.
class MockDepotBackend {
  MockDepotBackend({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _depots.addAll(MockDepotSeed.build(now()));
  }

  final DateTime Function() _clock;
  final List<DepotModel> _depots = [];
  final Map<String, SavedDepotDraft> _drafts = {};
  final Map<String, List<DepotDraftAttachment>> _attachments = {};
  final Map<String, Map<DepotDocumentType, DepotDocument>> _documents = {};
  int _sequence = 0;

  /// The server clock. Watermarks come from here, never from the caller.
  DateTime now() => _clock().toUtc();

  /// A fresh id, unique for the session.
  String nextId(String prefix) =>
      '$prefix-${(++_sequence).toString().padLeft(3, '0')}';

  /// Every depot, oldest change first, so paging is stable.
  List<DepotModel> get sorted => [..._depots]..sort((a, b) {
      final byTime = a.updatedAt.compareTo(b.updatedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

  /// Rows changed at or after [since].
  List<DepotModel> changedSince(DateTime since) =>
      sorted.where((d) => !d.updatedAt.isBefore(since.toUtc())).toList();

  /// Matches the platform id **or** the depot code, as the live routes do.
  DepotModel? find(String idOrCode) {
    for (final depot in _depots) {
      if (depot.id == idOrCode || depot.depotCode == idOrCode) return depot;
    }
    return null;
  }

  bool hasCode(String code) =>
      code.isNotEmpty && _depots.any((d) => d.depotCode == code);

  DepotModel insert(DepotModel depot) {
    _depots.add(depot);
    return depot;
  }

  // ── Registration drafts ────────────────────────────────────────────

  SavedDepotDraft? draft(String id) => _drafts[id];

  /// Stores [input] once. A resend of the same id answers the stored record
  /// with `isNew: false`, as the live route's 200 does.
  SavedDepotDraft saveDraft(NewDepotDraft input) {
    final existing = _drafts[input.id];
    if (existing != null) return existing.withIsNew(false);

    final stamp = now();
    final saved = SavedDepotDraft(
      id: input.id,
      version: 1,
      status: DepotStatus.pendingApproval.apiValue,
      nameEn: input.nameEn,
      kind: input.kind,
      createdAt: stamp,
    );
    _drafts[input.id] = saved;
    insert(_pendingDepotOf(input, stamp));
    return saved;
  }

  List<DepotDraftAttachment> attachmentsOf(String draftId) =>
      _attachments.putIfAbsent(draftId, () => []);

  // ── Documents ──────────────────────────────────────────────────────

  Map<DepotDocumentType, DepotDocument> documentsOf(String depotId) =>
      _documents.putIfAbsent(depotId, () => {});

  /// A registration as the directory lists it until HQ decides: no SAP
  /// number, `PendingApproval`, in the Waiting for Approval list.
  DepotModel _pendingDepotOf(NewDepotDraft input, DateTime stamp) {
    final contact = input.contacts.isEmpty ? null : input.contacts.first;
    final province = MockDepotFixtures.provinces[input.address.provinceCode] ??
        MockDepotFixtures.province;
    final street = input.address.street?.trim() ?? '';
    final area = input.salesAreas.isEmpty ? null : input.salesAreas.first;
    final location = input.location;
    final phone = input.telephone.isNotEmpty
        ? input.telephone
        : (input.mobilePhone ?? '');
    return DepotModel(
      id: input.id,
      depotCode: nextId('DPT-DEMO-NEW'),
      shopName: input.nameEn,
      enName: input.nameEn,
      khName: input.nameKh,
      ownerName: contact?.nameEn ?? contact?.nameKh ?? '',
      phone: phone,
      email: input.email,
      address: [street, province].where((p) => p.isNotEmpty).join(', '),
      province: province,
      district: '',
      territory: MockDepotFixtures.territory,
      latitude: location?.latitude ?? 0,
      longitude: location?.longitude ?? 0,
      creditLimit: input.creditLimit ?? 0,
      currency: MockDepotFixtures.currency,
      status: DepotStatus.pendingApproval,
      assignedRepId: MockDepotFixtures.repId,
      assignedRepName: MockDepotFixtures.repName,
      updatedAt: stamp,
      createdAt: stamp,
      salesOrg: area?.salesOrg,
      division: area?.division,
      depotGroup: area?.customerGroup,
      depotType: switch (input.kind) {
        MobileDepotKind.depot => DepotTypes.draft,
        MobileDepotKind.nonDepot => DepotTypes.nonDepotDraft,
      },
      createdBy: MockDepotFixtures.repCode,
      contacts: [
        if (contact != null)
          DepotContactModel(
            id: '${input.id}-contact-1',
            name: contact.nameEn ?? contact.nameKh ?? '',
            role: contact.role.name,
            phone: contact.phoneNumber ?? phone,
            email: contact.email,
          ),
      ],
      salesEmployees: const [MockDepotFixtures.demoRep],
      profile: DepotProfile(
        outletStatus: 'New',
        addressLine: street.isEmpty ? null : street,
        territory: MockDepotFixtures.territory,
      ),
    );
  }
}
