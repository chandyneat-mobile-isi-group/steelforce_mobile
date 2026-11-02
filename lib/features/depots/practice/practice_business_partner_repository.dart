import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_draft_seed.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';

/// [BusinessPartnerRepository] for a practice run.
///
/// * **Create / validate** succeed without a network call. A create files the
///   shop in the practice store — awaiting HQ, no SAP number — so it heads the
///   practice depot list.
/// * **Draft** lives in the store, never in the encrypted `BpDraftCache` box:
///   a rep's real half-finished registration is neither read nor overwritten.
///   With no practice draft yet, [loadDraft] answers with the seeded demo form
///   ([practiceSeedDraft]).
/// * **Reference catalogues** come from the real repository — read-only lookup
///   lists, so the dropdowns show the same options as the real form.
///
/// Forwards everything to [_real] once [PracticeWorld.isClosed].
class PracticeBusinessPartnerRepository implements BusinessPartnerRepository {
  PracticeBusinessPartnerRepository({
    required BusinessPartnerRepository real,
    required PracticeWorld world,
    required PracticeDepotStore store,
    required PracticeDemoPhotos photos,
  })  : _real = real,
        _world = world,
        _store = store,
        _photos = photos;

  final BusinessPartnerRepository _real;
  final PracticeWorld _world;
  final PracticeDepotStore _store;
  final PracticeDemoPhotos _photos;

  bool get _live => !_world.isClosed;

  @override
  ResultFuture<BusinessPartnerResult> createBusinessPartner(
    BusinessPartnerRequest request,
  ) async {
    if (!_live) return _real.createBusinessPartner(request);
    final depot = _store.register(request);
    return Success(
      BusinessPartnerResult(
        localId: depot.id,
        status: BpSubmissionStatus.pendingHq,
      ),
    );
  }

  @override
  ResultFuture<BusinessPartnerResult> validateBusinessPartner(
    BusinessPartnerRequest request,
  ) async {
    if (!_live) return _real.validateBusinessPartner(request);
    // What a clean dry run looks like: accepted, nothing created.
    return const Success(
      BusinessPartnerResult(
        localId: 'practice-validate',
        status: BpSubmissionStatus.pendingHq,
      ),
    );
  }

  @override
  Future<SapReferenceOptions> loadReferenceOptions({
    bool includeInactive = false,
  }) =>
      _real.loadReferenceOptions(includeInactive: includeInactive);

  @override
  Future<BpDepotDraft?> loadDraft() async {
    if (!_live) return _real.loadDraft();
    final saved = _store.draft;
    if (saved != null) return saved;
    return practiceSeedDraft(
      now: _store.now(),
      photos: await _photos.attachments(),
    );
  }

  @override
  Future<void> saveDraft(BpDepotDraft draft) async {
    if (!_live) return _real.saveDraft(draft);
    _store.draft = draft;
  }

  @override
  Future<void> clearDraft() async {
    if (!_live) return _real.clearDraft();
    _store.draft = null;
  }
}
