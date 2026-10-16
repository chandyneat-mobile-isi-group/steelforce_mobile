import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_registration_remote_data_source.dart';
import 'package:steelforce/features/depots/data/models/sap_reference_options.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';

void main() {
  late DemoNetwork network;
  late DemoDepotDirectory directory;
  late DemoRegistrationRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    directory = DemoDepotDirectory();
    source = DemoRegistrationRemoteDataSource(network, directory);
  });

  test('references reach the dropdowns as ERP options', () async {
    final options =
        SapReferenceOptions(await source.fetchRegistrationReferences());

    expect(options.isFromErp, isTrue);
    expect(options.depotGroup, hasLength(7));
    expect(options.priceGroupFor('05'), '51');
    expect(options.partnerGroup.map((o) => o.code), contains('Z001'));
    expect(options.synchronisedAt, isNotNull);
  });

  test('references can be narrowed to the kinds asked for', () async {
    final catalogue =
        await source.fetchRegistrationReferences(kinds: ['PaymentTerm']);

    expect(catalogue.catalogues.keys, ['PaymentTerm']);
  });

  test('offline fails as a network error', () async {
    network.setOnline(false);

    await expectLater(
      source.fetchRegistrationReferences(),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.network)),
    );
  });

  test('a draft round-trips through update and submit', () async {
    final draft = await source.createRegistrationDraft();
    expect(
        (await source.fetchActiveRegistrationDraft())?.draftId, draft.draftId);

    final updated = await source.updateRegistrationDraft(
      draftId: draft.draftId,
      changedFields: {'Name1': 'Demo Draft Hardware', 'City': 'Phnom Penh'},
    );
    expect(updated.fields['Name1'], 'Demo Draft Hardware');

    final result = await source.submitRegistrationDraft(draft.draftId);
    expect(result.status, 'CREATED');
    expect(result.depotCode, '1000000113');
    expect(directory.find(result.localId)?['shopName'], 'Demo Draft Hardware');

    // Submitted: no longer resumable, and no longer editable.
    expect(await source.fetchActiveRegistrationDraft(), isNull);
    await expectLater(
      source.updateRegistrationDraft(
          draftId: draft.draftId, changedFields: const {}),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('a deleted draft is gone', () async {
    final draft = await source.createRegistrationDraft();
    await source.deleteRegistrationDraft(draft.draftId);

    expect(await source.fetchRegistrationDrafts(), isEmpty);
    await expectLater(
      source.fetchRegistrationDraft(draft.draftId),
      throwsA(isA<ValidationFailure>()),
    );
  });
}
