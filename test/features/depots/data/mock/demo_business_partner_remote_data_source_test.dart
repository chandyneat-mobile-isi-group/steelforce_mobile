import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/depots/data/mock/demo_business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';

BusinessPartnerRequestModel _request({bool commit = true}) =>
    BusinessPartnerRequestModel(
      commit: commit,
      partnerCategory: '2',
      partnerGroup: 'Z001',
      bpRole: 'FLCU01',
      accountGroup: 'Z001',
      name1: 'Demo Corner Steel',
      name3: 'ហាងដែកសាកល្បង',
      coName: 'Demo Owner-Owner',
      district: 'Chamkar Mon',
      country: 'KH',
      region: '12',
      city: 'Phnom Penh',
      latitude: '11.55',
      longitude: '104.92',
      language: 'EN',
      mobilePhone: '012 000 777',
      salesOrg: '1000',
      distributionChannel: '10',
      division: '00',
      depotGroup: '02',
      salesOffice: '0001',
      salesGroup: '010',
      pricingProc: '1',
      deliveryPriority: '02',
      shippingCondition: '01',
      currency: 'USD',
      paymentTerms: 'TCOD',
      creditControlArea: '1000',
      taxCountry: 'KH',
      taxType: 'KH0',
      taxClass: '0',
      partnerFunction: 'ZE',
    );

void main() {
  late DemoNetwork network;
  late DemoDepotDirectory directory;
  late DemoBusinessPartnerRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    directory = DemoDepotDirectory();
    source = DemoBusinessPartnerRemoteDataSource(network, directory);
  });

  test('a committed registration gets a BP number and joins the book',
      () async {
    final result = await source.createBusinessPartner(_request());

    expect(result.isAccepted, isTrue);
    expect(result.status, BpSubmissionStatus.created);
    expect(result.depotNumber, '1000000113');
    final row = directory.find(result.localId)!;
    expect(row['shopName'], 'Demo Corner Steel');
    expect(row['customerCode'], result.depotNumber);
  });

  test('a dry run validates and stores nothing', () async {
    final before = directory.sorted.length;

    final result = await source.createBusinessPartner(_request(commit: false));

    expect(result.hasError, isFalse);
    expect(directory.sorted.length, before);
  });

  test('offline is a NetworkException, the "never sent" signal', () async {
    network.setOnline(false);

    await expectLater(
      source.createBusinessPartner(_request()),
      throwsA(isA<NetworkException>()),
    );
  });
}
