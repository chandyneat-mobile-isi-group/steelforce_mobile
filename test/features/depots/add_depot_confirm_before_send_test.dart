import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/depots/data/local/rep_sales_context_source.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';
import 'package:steelforce/features/depots/domain/entities/depot_document.dart';
import 'package:steelforce/features/depots/domain/repositories/business_partner_repository.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_document_repository.dart';
import 'package:steelforce/features/depots/presentation/bloc/add_depot_bloc.dart';
import 'package:steelforce/features/depots/presentation/bloc/business_partner_submission.dart';
import 'package:mocktail/mocktail.dart';

/// A registration is held on the device until the rep confirms on the review
/// step, and what is sent is the form as it stands at that tap.
///
/// The defect this guards against: reaching the documents step (or adding a
/// photo) used to create the business partner on the backend immediately, and
/// the final submit then short-circuited — so anything the rep corrected on
/// review was never sent.
class _MockRegistration extends Mock implements BusinessPartnerRepository {}

class _MockSubmission extends Mock implements BusinessPartnerSubmission {}

class _MockDocuments extends Mock implements DepotDocumentRepository {}

class _MockRepSource extends Mock implements RepSalesContextSource {}

const _rep = RepSalesContext(
  salesOrganization: '',
  salesOrganizationName: '',
  salesOffice: '',
  salesOfficeName: '',
  salesEmployeeId: '107576',
  salesEmployeeName: 'Sok Dara',
);

BpDepotDraft _completeDraft() {
  final draft = BpDepotDraft(
    nameEn: 'Sok Heng Hardware',
    nameKh: 'ហាង សុខ ហេង',
    cityCode: '12',
    districtCode: '1204',
    communeCode: '120101',
    postalCode: '120101',
    geoFix: GeoFix(
      latitude: 11.5449,
      longitude: 104.9160,
      capturedAt: DateTime.utc(2026, 8, 31, 8),
    ),
    mobilePhone: '012345678',
    contactPersonName: 'Sok Heng',
    contactPersonRole: 'owner',
    salesOrg: '0001',
    salesOffice: '0001',
    salesGroupCode: '010',
    depotGroup: '01',
  );
  for (final kind in ['outlet_front', 'outlet_inside', 'id_card']) {
    draft.attachments.add(BpAttachment(
      kind: kind,
      localPath: '/tmp/$kind.jpg',
      capturedAt: DateTime.utc(2026, 8, 31, 8),
    ));
  }
  return draft;
}

void main() {
  late _MockRegistration registration;
  late _MockSubmission submission;
  late _MockDocuments documents;
  late _MockRepSource repSource;

  /// Names seen by the backend, snapshotted at call time — the draft is
  /// mutable, so reading it after the fact would prove nothing.
  late List<String> sentNames;

  setUpAll(() {
    registerFallbackValue(BpDepotDraft());
    registerFallbackValue(_rep);
    registerFallbackValue(<PendingDepotDocument>[]);
  });

  setUp(() {
    registration = _MockRegistration();
    submission = _MockSubmission();
    documents = _MockDocuments();
    repSource = _MockRepSource();
    sentNames = [];

    when(() => registration.loadDraft()).thenAnswer((_) async => null);
    when(() => registration.loadReferenceOptions())
        .thenAnswer((_) async => SapReferenceOptions.empty);
    when(() => registration.saveDraft(any())).thenAnswer((_) async {});
    when(() => registration.clearDraft()).thenAnswer((_) async {});
    when(() => repSource.current()).thenAnswer((_) async => _rep);

    when(() => submission.submit(
          any(),
          rep: any(named: 'rep'),
          priceGroupResolver: any(named: 'priceGroupResolver'),
        )).thenAnswer((invocation) async {
      final draft = invocation.positionalArguments.first as BpDepotDraft;
      sentNames.add(draft.nameEn);
      return const BpSubmissionCreated(BusinessPartnerResult(
        depotNumber: '',
        localId: 'depot-1',
        status: BpSubmissionStatus.pendingHq,
      ));
    });
    when(() => documents.uploadAll(
          depotId: any(named: 'depotId'),
          documents: any(named: 'documents'),
          onProgress: any(named: 'onProgress'),
        )).thenAnswer((_) async => const Success(DepotDocumentUploadOutcome()));
  });

  AddDepotBloc build({BpDepotDraft? draft}) => AddDepotBloc(
        repository: registration,
        documents: documents,
        submission: submission,
        repSource: repSource,
        initialDraft: draft ?? _completeDraft(),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void verifyNothingSent() {
    verifyNever(() => submission.submit(
          any(),
          rep: any(named: 'rep'),
          priceGroupResolver: any(named: 'priceGroupResolver'),
        ));
    verifyNever(() => documents.uploadAll(
          depotId: any(named: 'depotId'),
          documents: any(named: 'documents'),
          onProgress: any(named: 'onProgress'),
        ));
  }

  group('nothing leaves the device before the rep confirms', () {
    test('walking every step to review sends nothing', () async {
      final bloc = build();
      bloc.add(const OpenForm());
      await settle();
      for (var i = 0; i < BpFormStep.values.length; i++) {
        bloc.add(const NextStep());
        await settle();
      }

      expect(bloc.state.currentStep, BpFormStep.review);
      verifyNothingSent();
      await bloc.close();
    });

    test('jumping to the documents step sends nothing', () async {
      final bloc = build();
      bloc.add(const GoToStep(BpFormStep.documents));
      await settle();

      verifyNothingSent();
      expect(bloc.state.draft.isDepotCreatedOnServer, isFalse);
      await bloc.close();
    });

    test('adding a photograph holds it locally and sends nothing', () async {
      final bloc = build(draft: _completeDraft()..attachments.clear());
      bloc.add(AttachmentAdded(BpAttachment(
        kind: 'outlet_front',
        localPath: '/tmp/front.jpg',
        capturedAt: DateTime.utc(2026, 8, 31, 8),
      )));
      await settle();

      final photo = bloc.state.draft.getAttachment('outlet_front');
      expect(photo, isNotNull);
      expect(photo!.isUploading, isFalse);
      expect(photo.isUploaded, isFalse);
      verifyNothingSent();
      // ...but it is saved, so a killed app keeps it.
      verify(() => registration.saveDraft(any())).called(greaterThan(0));
      await bloc.close();
    });

    test('captured (not uploaded) photographs are enough to reach review',
        () async {
      final bloc = build();
      bloc.add(const GoToStep(BpFormStep.documents));
      await settle();
      bloc.add(const NextStep());
      await settle();

      expect(bloc.state.currentStep, BpFormStep.review);
      await bloc.close();
    });

    test('a missing required photograph still blocks the documents step',
        () async {
      final draft = _completeDraft()
        ..attachments.removeWhere((a) => a.kind == 'id_card');
      final bloc = build(draft: draft);
      bloc.add(const GoToStep(BpFormStep.documents));
      await settle();
      bloc.add(const NextStep());
      await settle();

      expect(bloc.state.currentStep, BpFormStep.documents);
      expect(bloc.state.errors, contains('id_card'));
      await bloc.close();
    });
  });

  group('the confirmed form is the one sent', () {
    test('an edit made on review, after the documents step, is sent', () async {
      final bloc = build();
      bloc.add(const OpenForm());
      await settle();
      bloc.add(const GoToStep(BpFormStep.documents));
      await settle();
      bloc.add(const GoToStep(BpFormStep.review));
      await settle();

      // The rep spots a typo on review and fixes it.
      bloc.add(const GoToStep(BpFormStep.identity));
      bloc.add(DraftChanged((d) => d.nameEn = 'Sok Heng Steel'));
      bloc.add(const GoToStep(BpFormStep.review));
      await settle();

      bloc.add(const SubmitToHQ());
      final done = await bloc.stream.firstWhere((s) =>
          s.status == AddDepotStatus.success ||
          s.status == AddDepotStatus.failure);

      expect(done.status, AddDepotStatus.success);
      expect(sentNames, ['Sok Heng Steel'],
          reason: 'exactly one create, carrying the corrected name');
      await bloc.close();
    });

    test('photographs go up after the create, against its id', () async {
      final order = <String>[];
      when(() => submission.submit(
            any(),
            rep: any(named: 'rep'),
            priceGroupResolver: any(named: 'priceGroupResolver'),
          )).thenAnswer((_) async {
        order.add('create');
        return const BpSubmissionCreated(BusinessPartnerResult(
          depotNumber: '',
          localId: 'depot-9',
          status: BpSubmissionStatus.pendingHq,
        ));
      });
      when(() => documents.uploadAll(
            depotId: any(named: 'depotId'),
            documents: any(named: 'documents'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async {
        order.add('upload');
        return const Success(DepotDocumentUploadOutcome());
      });

      final bloc = build();
      bloc.add(const SubmitToHQ());
      await bloc.stream.firstWhere((s) => s.status == AddDepotStatus.success);

      expect(order, ['create', 'upload']);
      verify(() => documents.uploadAll(
            depotId: 'depot-9',
            documents: any(named: 'documents'),
            onProgress: any(named: 'onProgress'),
          )).called(1);
      await bloc.close();
    });

    test('the signed-in rep\'s identity is what is sent', () async {
      RepSalesContext? sentRep;
      when(() => submission.submit(
            any(),
            rep: any(named: 'rep'),
            priceGroupResolver: any(named: 'priceGroupResolver'),
          )).thenAnswer((invocation) async {
        sentRep = invocation.namedArguments[#rep] as RepSalesContext;
        return const BpSubmissionCreated(BusinessPartnerResult(
          depotNumber: '',
          localId: 'depot-1',
          status: BpSubmissionStatus.pendingHq,
        ));
      });

      final bloc = build();
      bloc.add(const OpenForm());
      await settle();
      bloc.add(const SubmitToHQ());
      await bloc.stream.firstWhere((s) => s.status == AddDepotStatus.success);

      expect(sentRep?.salesEmployeeId, '107576');
      await bloc.close();
    });
  });

  group('no signed-in identity', () {
    test('submit is refused before any network call, and the form is kept',
        () async {
      when(() => repSource.current()).thenAnswer((_) async => null);

      final bloc = build();
      bloc.add(const OpenForm());
      await settle();
      expect(bloc.hasRepIdentity, isFalse);
      // No one else's number is offered in its place.
      expect(bloc.rep.salesEmployeeId, isEmpty);

      bloc.add(const SubmitToHQ());
      final state = await bloc.stream
          .firstWhere((s) => s.status == AddDepotStatus.failure);

      expect(state.errorMessage, 'add_depot.error.rep_identity_unavailable');
      verifyNothingSent();
      verify(() => registration.saveDraft(any())).called(greaterThan(0));
      verifyNever(() => registration.clearDraft());
      await bloc.close();
    });

    test('an identity that appears after the form opened is used on submit',
        () async {
      var calls = 0;
      when(() => repSource.current())
          .thenAnswer((_) async => calls++ == 0 ? null : _rep);

      final bloc = build();
      bloc.add(const OpenForm());
      await settle();
      expect(bloc.hasRepIdentity, isFalse);

      bloc.add(const SubmitToHQ());
      final state = await bloc.stream.firstWhere((s) =>
          s.status == AddDepotStatus.success ||
          s.status == AddDepotStatus.failure);

      expect(state.status, AddDepotStatus.success);
      expect(bloc.hasRepIdentity, isTrue);
      await bloc.close();
    });

    test('a throwing identity source is treated as no identity', () async {
      when(() => repSource.current()).thenThrow(StateError('boom'));

      final bloc = build();
      bloc.add(const SubmitToHQ());
      final state = await bloc.stream
          .firstWhere((s) => s.status == AddDepotStatus.failure);

      expect(state.errorMessage, 'add_depot.error.rep_identity_unavailable');
      verifyNothingSent();
      await bloc.close();
    });

    test('the SAP dry run is refused too', () async {
      when(() => repSource.current()).thenAnswer((_) async => null);

      final bloc = build();
      bloc.add(const ValidateWithSap());
      await settle();

      expect(
          bloc.state.errorMessage, 'add_depot.error.rep_identity_unavailable');
      verifyNever(() => submission.validate(
            any(),
            rep: any(named: 'rep'),
            priceGroupResolver: any(named: 'priceGroupResolver'),
          ));
      await bloc.close();
    });
  });

  group('a draft left by an older build that registered early', () {
    test('is not created a second time; outstanding photos are sent', () async {
      final draft = _completeDraft()
        ..serverDepotId = 'depot-legacy'
        ..depotNumber = '';
      // One slot reached the server under the old build; two did not.
      draft.attachments[0] = draft.attachments[0].copyWith(isUploaded: true);

      List<PendingDepotDocument>? sent;
      when(() => documents.uploadAll(
            depotId: any(named: 'depotId'),
            documents: any(named: 'documents'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((invocation) async {
        sent =
            invocation.namedArguments[#documents] as List<PendingDepotDocument>;
        return const Success(DepotDocumentUploadOutcome());
      });

      final bloc = build(draft: draft);
      bloc.add(const SubmitToHQ());
      final state = await bloc.stream
          .firstWhere((s) => s.status == AddDepotStatus.success);

      expect(state.status, AddDepotStatus.success);
      verifyNever(() => submission.submit(
            any(),
            rep: any(named: 'rep'),
            priceGroupResolver: any(named: 'priceGroupResolver'),
          ));
      expect(sent!.map((d) => d.type),
          [DepotDocumentType.insideStore, DepotDocumentType.idCard]);
      await bloc.close();
    });

    test('retrying a failed slot clears it locally without a network call',
        () async {
      final draft = _completeDraft();
      draft.attachments[0] =
          draft.attachments[0].copyWith(uploadError: 'failed');

      final bloc = build(draft: draft);
      bloc.add(const RetryUploadAttachment('outlet_front'));
      await settle();

      expect(
          bloc.state.draft.getAttachment('outlet_front')!.uploadError, isNull);
      verifyNothingSent();
      await bloc.close();
    });
  });
}
