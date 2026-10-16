// =============================================================================
// business_partner_request_model.dart
//
// Wire form of [BusinessPartnerRequest] for
// `POST /api/v1/mobile/depots/business-partner`.
//
// The key casing is not a style choice and must not be normalised. The
// contract mixes three conventions in one object — `PartnerCategory`,
// `SALESBLOCK`, `submitToSap` — because it is a thin passthrough over an SAP
// structure where `SALESBLOCK` and `BLOCKFLAG` are the ABAP field names and
// `submitToSap` is the middleware's own flag. Anything that "tidies" these
// loses the field silently: the server drops the unknown key and SAP receives
// a blank.
//
// Every key is emitted on every request, including the empty ones. The sample
// payload sends `"DepotNumber": ""` rather than omitting it, and a BAPI
// distinguishes "not supplied" from "supplied as blank" — for `OrderBlock` and
// friends the difference is between leaving an existing block alone and
// clearing it.
// =============================================================================

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';

class BusinessPartnerRequestModel extends BusinessPartnerRequest {
  const BusinessPartnerRequestModel({
    super.commit,
    super.depotNumber,
    required super.partnerCategory,
    required super.partnerGroup,
    required super.bpRole,
    required super.accountGroup,
    required super.name1,
    super.name2,
    super.name3,
    super.coName,
    super.searchTerm1,
    super.searchTerm2,
    super.district,
    required super.country,
    required super.region,
    super.city,
    super.street,
    super.houseNo,
    super.postalCode,
    super.latitude,
    super.longitude,
    required super.language,
    super.telephone,
    super.mobilePhone,
    required super.salesOrg,
    required super.distributionChannel,
    required super.division,
    required super.depotGroup,
    required super.salesOffice,
    required super.salesGroup,
    super.priceGroup,
    required super.pricingProc,
    required super.deliveryPriority,
    required super.shippingCondition,
    required super.currency,
    required super.paymentTerms,
    super.creditLimit,
    required super.creditControlArea,
    required super.taxCountry,
    required super.taxType,
    required super.taxClass,
    required super.partnerFunction,
    super.partnerCounter,
    super.personnelNumber,
    super.orderBlock,
    super.salesBlock,
    super.blockFlag,
    super.submitToSap,
  });

  /// Lifts a domain request into its wire form without re-listing 47 fields at
  /// every call site.
  factory BusinessPartnerRequestModel.fromEntity(
    BusinessPartnerRequest e,
  ) =>
      BusinessPartnerRequestModel(
        commit: e.commit,
        depotNumber: e.depotNumber,
        partnerCategory: e.partnerCategory,
        partnerGroup: e.partnerGroup,
        bpRole: e.bpRole,
        accountGroup: e.accountGroup,
        name1: e.name1,
        name2: e.name2,
        name3: e.name3,
        coName: e.coName,
        searchTerm1: e.searchTerm1,
        searchTerm2: e.searchTerm2,
        district: e.district,
        country: e.country,
        region: e.region,
        city: e.city,
        street: e.street,
        houseNo: e.houseNo,
        postalCode: e.postalCode,
        latitude: e.latitude,
        longitude: e.longitude,
        language: e.language,
        telephone: e.telephone,
        mobilePhone: e.mobilePhone,
        salesOrg: e.salesOrg,
        distributionChannel: e.distributionChannel,
        division: e.division,
        depotGroup: e.depotGroup,
        salesOffice: e.salesOffice,
        salesGroup: e.salesGroup,
        priceGroup: e.priceGroup,
        pricingProc: e.pricingProc,
        deliveryPriority: e.deliveryPriority,
        shippingCondition: e.shippingCondition,
        currency: e.currency,
        paymentTerms: e.paymentTerms,
        creditLimit: e.creditLimit,
        creditControlArea: e.creditControlArea,
        taxCountry: e.taxCountry,
        taxType: e.taxType,
        taxClass: e.taxClass,
        partnerFunction: e.partnerFunction,
        partnerCounter: e.partnerCounter,
        personnelNumber: e.personnelNumber,
        orderBlock: e.orderBlock,
        salesBlock: e.salesBlock,
        blockFlag: e.blockFlag,
        submitToSap: e.submitToSap,
      );

  /// Reads a payload back — used by the offline queue, which stores the
  /// serialised body rather than the draft. Storing the body means a queued
  /// registration replays byte-identically after an app upgrade that changed
  /// the mapper, instead of being re-derived under new rules the rep never saw.
  factory BusinessPartnerRequestModel.fromJson(DataMap json) {
    String s(String key) => json[key]?.toString() ?? '';
    bool b(String key, {bool orElse = false}) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true' || v == '1' || v == 'X';
      return orElse;
    }

    return BusinessPartnerRequestModel(
      commit: b('Commit', orElse: true),
      depotNumber: s('CustomerNumber'),
      partnerCategory: s('PartnerCategory'),
      partnerGroup: s('PartnerGroup'),
      bpRole: s('BpRole'),
      accountGroup: s('AccountGroup'),
      name1: s('Name1'),
      name2: s('Name2'),
      name3: s('Name3'),
      coName: s('CoName'),
      searchTerm1: s('SearchTerm1'),
      searchTerm2: s('SearchTerm2'),
      district: s('District'),
      country: s('Country'),
      region: s('Region'),
      city: s('City'),
      street: s('Street'),
      houseNo: s('HouseNo'),
      postalCode: s('PostalCode'),
      latitude: s('Latitude'),
      longitude: s('Longitude'),
      language: s('Language'),
      telephone: s('Telephone'),
      mobilePhone: s('MobilePhone'),
      salesOrg: s('SalesOrg'),
      distributionChannel: s('DistributionChannel'),
      division: s('Division'),
      depotGroup: s('CustomerGroup'),
      salesOffice: s('SalesOffice'),
      salesGroup: s('SalesGroup'),
      priceGroup: s('PriceGroup'),
      pricingProc: s('PricingProc'),
      deliveryPriority: s('DeliveryPriority'),
      shippingCondition: s('ShippingCondition'),
      currency: s('Currency'),
      paymentTerms: s('PaymentTerms'),
      creditLimit: s('CreditLimit'),
      creditControlArea: s('CreditControlArea'),
      taxCountry: s('TaxCountry'),
      taxType: s('TaxType'),
      taxClass: s('TaxClass'),
      partnerFunction: s('PartnerFunction'),
      partnerCounter: s('PartnerCounter'),
      personnelNumber: s('PersonnelNumber'),
      orderBlock: s('OrderBlock'),
      salesBlock: s('SALESBLOCK'),
      blockFlag: s('BLOCKFLAG'),
      submitToSap: b('submitToSap', orElse: true),
    );
  }

  /// The request body. Key order follows the API sample so a diff of two
  /// captured payloads stays readable.
  DataMap toJson() => {
        'Commit': commit,
        'CustomerNumber': depotNumber,

        'PartnerCategory': partnerCategory,
        'PartnerGroup': partnerGroup,
        'BpRole': bpRole,
        'AccountGroup': accountGroup,

        'Name1': name1,
        'Name2': name2,
        'Name3': name3,
        'CoName': coName,
        'SearchTerm1': searchTerm1,
        'SearchTerm2': searchTerm2,

        'District': district,
        'Country': country,
        'Region': region,
        'City': city,
        'Street': street,
        'HouseNo': houseNo,
        'PostalCode': postalCode,
        'Latitude': latitude,
        'Longitude': longitude,

        'Language': language,
        'Telephone': telephone,
        'MobilePhone': mobilePhone,

        'SalesOrg': salesOrg,
        'DistributionChannel': distributionChannel,
        'Division': division,
        'CustomerGroup': depotGroup,
        'SalesOffice': salesOffice,
        'SalesGroup': salesGroup,
        'PriceGroup': priceGroup,
        'PricingProc': pricingProc,
        'DeliveryPriority': deliveryPriority,
        'ShippingCondition': shippingCondition,
        'Currency': currency,
        'PaymentTerms': paymentTerms,
        'CreditLimit': creditLimit,
        'CreditControlArea': creditControlArea,

        'TaxCountry': taxCountry,
        'TaxType': taxType,
        'TaxClass': taxClass,

        'PartnerFunction': partnerFunction,
        'PartnerCounter': partnerCounter,
        'PersonnelNumber': personnelNumber,

        // ABAP field names, upper-cased on the wire. Not a typo.
        'OrderBlock': orderBlock,
        'SALESBLOCK': salesBlock,
        'BLOCKFLAG': blockFlag,

        'submitToSap': submitToSap,
      };
}
