import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/local/rep_sales_context_source.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';
import 'package:steelforce/features/depots/practice/practice_depot_store.dart';

// The smaller depot stand-ins for a practice run. Each wraps the real
// implementation and forwards every call to it once the world is closed, so
// one captured by a base-scope singleton degrades to real behaviour.

/// Evidence uploads during practice: every photograph "uploads" at once and
/// nothing leaves the handset.
class PracticeDepotDocumentRepository implements DepotDocumentRepository {
  PracticeDepotDocumentRepository({
    required DepotDocumentRepository real,
    required PracticeWorld world,
  })  : _real = real,
        _world = world;

  final DepotDocumentRepository _real;
  final PracticeWorld _world;

  bool get _live => !_world.isClosed;

  @override
  ResultFuture<DepotDocumentsState> fetch(String depotId) async {
    if (!_live) return _real.fetch(depotId);
    return const Success(DepotDocumentsState.empty);
  }

  @override
  ResultFuture<DepotDocumentUploadOutcome> uploadAll({
    required String depotId,
    required List<PendingDepotDocument> documents,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (!_live) {
      return _real.uploadAll(
        depotId: depotId,
        documents: documents,
        onProgress: onProgress,
      );
    }
    for (var i = 0; i < documents.length; i++) {
      onProgress?.call(i + 1, documents.length);
    }
    return Success(
      DepotDocumentUploadOutcome(
        uploaded: [for (final d in documents) d.type],
      ),
    );
  }

  @override
  ResultFuture<void> delete({
    required String depotId,
    required String documentId,
  }) async {
    if (!_live) return _real.delete(depotId: depotId, documentId: documentId);
    return const Success(null);
  }
}

/// The registration outbox during practice: empty and inert.
///
/// A practice submit never fails for want of a connection, so nothing should
/// reach [enqueue]; should anything try, it is accepted and dropped rather than
/// written into the encrypted queue the sync engine would replay to SAP. The
/// queue screens show nothing during practice, and the rep's real queued
/// registrations are untouched — they are simply not shown until it ends.
class PracticeDepotRegistrationOutbox implements DepotRegistrationOutbox {
  PracticeDepotRegistrationOutbox({
    required DepotRegistrationOutbox real,
    required PracticeWorld world,
  })  : _real = real,
        _world = world;

  final DepotRegistrationOutbox _real;
  final PracticeWorld _world;

  bool get _live => !_world.isClosed;

  @override
  ResultFuture<String> enqueue({
    required BusinessPartnerRequest request,
    required String depotName,
    required List<PendingDepotDocument> photos,
    bool mayHaveLanded = false,
    String? message,
    Map<String, dynamic>? draftSnapshot,
  }) async {
    if (!_live) {
      return _real.enqueue(
        request: request,
        depotName: depotName,
        photos: photos,
        mayHaveLanded: mayHaveLanded,
        message: message,
        draftSnapshot: draftSnapshot,
      );
    }
    return const Success('practice-registration');
  }

  @override
  ResultFuture<String> enqueueDraft({
    required String clientDraftId,
    required String depotName,
    required Map<String, dynamic> draftSnapshot,
    required List<PendingDepotDocument> photos,
  }) async {
    if (!_live) {
      return _real.enqueueDraft(
        clientDraftId: clientDraftId,
        depotName: depotName,
        draftSnapshot: draftSnapshot,
        photos: photos,
      );
    }
    return const Success('practice-registration');
  }

  @override
  Future<void> drain() async {
    if (!_live) return _real.drain();
  }

  @override
  Stream<List<PendingDepotRegistration>> watchAll() {
    if (!_live) return _real.watchAll();
    return Stream.value(const []);
  }

  @override
  Future<void> expedite() async {
    if (!_live) return _real.expedite();
  }

  @override
  Future<int> countUnsent() async {
    if (!_live) return _real.countUnsent();
    return 0;
  }

  @override
  Future<int> countSendable() async {
    if (!_live) return _real.countSendable();
    return 0;
  }

  @override
  ResultFuture<void> retry(String id) async {
    if (!_live) return _real.retry(id);
    return const Success(null);
  }

  @override
  ResultFuture<void> discard(String id) async {
    if (!_live) return _real.discard(id);
    return const Success(null);
  }

  @override
  ResultFuture<void> reopenAsDraft(String id) async {
    if (!_live) return _real.reopenAsDraft(id);
    return const Success(null);
  }
}

/// The stop screen's outlet profile during practice.
///
/// A practice depot id is answered from the practice store — any practice id,
/// so a demo visit stop always has a profile to show. A real id is passed to
/// the real repository (a read).
class PracticeDepotStopInformationRepository
    implements DepotStopInformationRepository {
  PracticeDepotStopInformationRepository({
    required DepotStopInformationRepository real,
    required PracticeWorld world,
    required PracticeDepotStore store,
  })  : _real = real,
        _world = world,
        _store = store;

  final DepotStopInformationRepository _real;
  final PracticeWorld _world;
  final PracticeDepotStore _store;

  @override
  ResultFuture<DepotStopInformation> fetch(String depotId) async {
    if (_world.isClosed || !PracticeIds.isPractice(depotId)) {
      return _real.fetch(depotId);
    }
    final depot = _store.byId(depotId) ?? _store.byId(PracticeIds.depotId)!;
    return Success(_profileOf(depot));
  }

  static DepotStopInformation _profileOf(Depot depot) {
    final currency = depot.currency;
    return DepotStopInformation(
      outlet: DepotOutletProfile(
        id: depot.id,
        code: depot.depotCode,
        name: depot.shopName,
        nameKh: depot.khName,
        contact: depot.ownerName.isEmpty ? null : depot.ownerName,
        phone: depot.phone,
        address: depot.address,
        outletType: 'Retail',
      ),
      credit: DepotCreditProfile(
        creditLimit: Money(depot.creditLimit, currency),
        creditBalance: Money(depot.creditBalance, currency),
        availableCredit: Money(depot.availableCredit, currency),
        currency: currency,
        paymentTermCode: 'TCOD',
        paymentTermLabel: 'COD-Cash on Delivery',
        paymentTermDays: 0,
      ),
    );
  }
}

/// The rep's sales context during practice.
///
/// The real one when there is a signed-in rep. Without one — a guest
/// rehearsing before sign-in — a demo context, because the wizard refuses to
/// submit without a personnel number and the lesson would otherwise end on an
/// error it is not teaching. Nothing is sent, so the demo number reaches no
/// one.
class PracticeRepSalesContextSource implements RepSalesContextSource {
  PracticeRepSalesContextSource({
    required RepSalesContextSource real,
    required PracticeWorld world,
  })  : _real = real,
        _world = world;

  final RepSalesContextSource _real;
  final PracticeWorld _world;

  static const demoRep = RepSalesContext(
    salesOrganization: SapBpConst.salesOrg,
    salesOrganizationName: 'Phnom Penh (ISI)',
    salesOffice: SapBpConst.salesOffice,
    salesOfficeName: 'Phnom Penh',
    salesEmployeeId: 'PRACTICE',
    salesEmployeeName: 'Practice',
  );

  @override
  Future<RepSalesContext?> current() async {
    if (_world.isClosed) return _real.current();
    RepSalesContext? rep;
    try {
      rep = await _real.current();
    } on Object {
      rep = null;
    }
    return rep ?? demoRep;
  }
}
