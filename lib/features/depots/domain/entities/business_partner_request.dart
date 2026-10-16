// =============================================================================
// business_partner_request.dart
//
// The registration payload as a domain value, one field per key that
// `POST /api/v1/mobile/depots/business-partner` accepts.
//
// Every field is a `String` even where the value is numeric (`Latitude`,
// `PersonnelNumber`, `PostalCode`). That mirrors the wire contract rather than
// improving on it: SAP's BAPI structures are CHAR fields, a leading zero is
// significant (`SalesOrg` `0001` is not `1`), and parsing to `num` here would
// mean re-formatting on the way out and getting `0001` wrong exactly once.
//
// The two genuine booleans (`Commit`, `submitToSap`) are booleans, because they
// are control flags the app decides rather than master data it forwards.
// =============================================================================

import 'package:equatable/equatable.dart';

class BusinessPartnerRequest extends Equatable {
  const BusinessPartnerRequest({
    // --- Control ---------------------------------------------------------
    this.commit = true,
    this.depotNumber = '',

    // --- BP header -------------------------------------------------------
    required this.partnerCategory,
    required this.partnerGroup,
    required this.bpRole,
    required this.accountGroup,

    // --- Names -----------------------------------------------------------
    required this.name1,
    this.name2 = '',
    this.name3 = '',
    this.coName = '',
    this.searchTerm1 = '',
    this.searchTerm2 = '',

    // --- Address ---------------------------------------------------------
    this.district = '',
    required this.country,
    required this.region,
    this.city = '',
    this.street = '',
    this.houseNo = '',
    this.postalCode = '',
    this.latitude = '',
    this.longitude = '',

    // --- Communication ---------------------------------------------------
    required this.language,
    this.telephone = '',
    this.mobilePhone = '',

    // --- Sales area & terms ----------------------------------------------
    required this.salesOrg,
    required this.distributionChannel,
    required this.division,
    required this.depotGroup,
    required this.salesOffice,
    required this.salesGroup,
    this.priceGroup = '',
    required this.pricingProc,
    required this.deliveryPriority,
    required this.shippingCondition,
    required this.currency,
    required this.paymentTerms,
    this.creditLimit = '',
    required this.creditControlArea,

    // --- Tax -------------------------------------------------------------
    required this.taxCountry,
    required this.taxType,
    required this.taxClass,

    // --- Partner function ------------------------------------------------
    required this.partnerFunction,
    this.partnerCounter = '001',
    this.personnelNumber = '',

    // --- Blocks ----------------------------------------------------------
    this.orderBlock = '',
    this.salesBlock = '',
    this.blockFlag = '',

    // --- Routing ---------------------------------------------------------
    this.submitToSap = true,
  });

  /// `Commit` — tells the middleware to commit the BAPI unit of work.
  ///
  /// Sending `false` runs SAP's own validation and rolls back, which is the
  /// only way to find out whether a record is acceptable without creating it.
  /// See [BusinessPartnerRepository.validateBusinessPartner].
  final bool commit;

  /// `DepotNumber` — empty on create. Carries the SAP number when the call
  /// is extending or correcting an existing partner.
  final String depotNumber;

  final String partnerCategory;
  final String partnerGroup;
  final String bpRole;
  final String accountGroup;

  final String name1;
  final String name2;
  final String name3;
  final String coName;
  final String searchTerm1;
  final String searchTerm2;

  /// District *name*, not the gazetteer code — see the mapper for why.
  final String district;
  final String country;
  final String region;

  /// City / province *name*, not the gazetteer code.
  final String city;
  final String street;
  final String houseNo;
  final String postalCode;
  final String latitude;
  final String longitude;

  /// SAP language key (`E`), not the app locale (`EN`).
  final String language;
  final String telephone;
  final String mobilePhone;

  final String salesOrg;
  final String distributionChannel;
  final String division;
  final String depotGroup;
  final String salesOffice;
  final String salesGroup;
  final String priceGroup;
  final String pricingProc;
  final String deliveryPriority;
  final String shippingCondition;
  final String currency;
  final String paymentTerms;
  final String creditLimit;
  final String creditControlArea;

  final String taxCountry;
  final String taxType;
  final String taxClass;

  final String partnerFunction;
  final String partnerCounter;
  final String personnelNumber;

  final String orderBlock;
  final String salesBlock;
  final String blockFlag;

  /// `submitToSap` — distinct from [commit].
  ///
  /// `commit` is about SAP's transaction; `submitToSap` is about whether the
  /// backend forwards the record to SAP at all or parks it for HQ review. A
  /// record can be stored with `submitToSap: false` and pushed later.
  final bool submitToSap;

  /// True when the record carries every field group SAP needs to accept it.
  ///
  /// Checked here as well as in the form because a draft can reach the
  /// repository from the offline queue, where the wizard's per-step validation
  /// never ran. A record missing the sales area saves happily and then can
  /// never be delivered.
  bool get isRegisterable => missingForRegistration.isEmpty;

  /// The wire fields a record cannot be registered without, by name.
  ///
  /// Returned as a list rather than a bool so the refusal can say which field
  /// is missing. A generic "incomplete" here is unactionable: the wizard has
  /// already validated everything the rep can see, so anything that fails at
  /// this point is a field the rep never typed and cannot find.
  List<String> get missingForRegistration => [
        if (name1.trim().isEmpty) 'Name1',
        if (salesOrg.isEmpty) 'SalesOrg',
        if (distributionChannel.isEmpty) 'DistributionChannel',
        if (division.isEmpty) 'Division',
        if (country.isEmpty) 'Country',
        // SAP's `PERNR` is numeric, and the mapper strips non-digits — so an
        // empty value here means the session supplied something that was not a
        // personnel number at all. Refused rather than sent: the middleware
        // accepts the record and the SAP push then fails, leaving a
        // registration that exists on the backend and not in the ERP, with
        // nothing in the mobile log to explain it.
        if (personnelNumber.isEmpty) 'PersonnelNumber',
      ];

  BusinessPartnerRequest copyWith({
    bool? commit,
    String? depotNumber,
    String? partnerCategory,
    String? partnerGroup,
    String? bpRole,
    String? accountGroup,
    String? name1,
    String? name2,
    String? name3,
    String? coName,
    String? searchTerm1,
    String? searchTerm2,
    String? district,
    String? country,
    String? region,
    String? city,
    String? street,
    String? houseNo,
    String? postalCode,
    String? latitude,
    String? longitude,
    String? language,
    String? telephone,
    String? mobilePhone,
    String? salesOrg,
    String? distributionChannel,
    String? division,
    String? depotGroup,
    String? salesOffice,
    String? salesGroup,
    String? priceGroup,
    String? pricingProc,
    String? deliveryPriority,
    String? shippingCondition,
    String? currency,
    String? paymentTerms,
    String? creditLimit,
    String? creditControlArea,
    String? taxCountry,
    String? taxType,
    String? taxClass,
    String? partnerFunction,
    String? partnerCounter,
    String? personnelNumber,
    String? orderBlock,
    String? salesBlock,
    String? blockFlag,
    bool? submitToSap,
  }) {
    return BusinessPartnerRequest(
      commit: commit ?? this.commit,
      depotNumber: depotNumber ?? this.depotNumber,
      partnerCategory: partnerCategory ?? this.partnerCategory,
      partnerGroup: partnerGroup ?? this.partnerGroup,
      bpRole: bpRole ?? this.bpRole,
      accountGroup: accountGroup ?? this.accountGroup,
      name1: name1 ?? this.name1,
      name2: name2 ?? this.name2,
      name3: name3 ?? this.name3,
      coName: coName ?? this.coName,
      searchTerm1: searchTerm1 ?? this.searchTerm1,
      searchTerm2: searchTerm2 ?? this.searchTerm2,
      district: district ?? this.district,
      country: country ?? this.country,
      region: region ?? this.region,
      city: city ?? this.city,
      street: street ?? this.street,
      houseNo: houseNo ?? this.houseNo,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      language: language ?? this.language,
      telephone: telephone ?? this.telephone,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      salesOrg: salesOrg ?? this.salesOrg,
      distributionChannel: distributionChannel ?? this.distributionChannel,
      division: division ?? this.division,
      depotGroup: depotGroup ?? this.depotGroup,
      salesOffice: salesOffice ?? this.salesOffice,
      salesGroup: salesGroup ?? this.salesGroup,
      priceGroup: priceGroup ?? this.priceGroup,
      pricingProc: pricingProc ?? this.pricingProc,
      deliveryPriority: deliveryPriority ?? this.deliveryPriority,
      shippingCondition: shippingCondition ?? this.shippingCondition,
      currency: currency ?? this.currency,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      creditControlArea: creditControlArea ?? this.creditControlArea,
      taxCountry: taxCountry ?? this.taxCountry,
      taxType: taxType ?? this.taxType,
      taxClass: taxClass ?? this.taxClass,
      partnerFunction: partnerFunction ?? this.partnerFunction,
      partnerCounter: partnerCounter ?? this.partnerCounter,
      personnelNumber: personnelNumber ?? this.personnelNumber,
      orderBlock: orderBlock ?? this.orderBlock,
      salesBlock: salesBlock ?? this.salesBlock,
      blockFlag: blockFlag ?? this.blockFlag,
      submitToSap: submitToSap ?? this.submitToSap,
    );
  }

  @override
  List<Object?> get props => [
        commit,
        depotNumber,
        partnerCategory,
        partnerGroup,
        bpRole,
        accountGroup,
        name1,
        name2,
        name3,
        coName,
        searchTerm1,
        searchTerm2,
        district,
        country,
        region,
        city,
        street,
        houseNo,
        postalCode,
        latitude,
        longitude,
        language,
        telephone,
        mobilePhone,
        salesOrg,
        distributionChannel,
        division,
        depotGroup,
        salesOffice,
        salesGroup,
        priceGroup,
        pricingProc,
        deliveryPriority,
        shippingCondition,
        currency,
        paymentTerms,
        creditLimit,
        creditControlArea,
        taxCountry,
        taxType,
        taxClass,
        partnerFunction,
        partnerCounter,
        personnelNumber,
        orderBlock,
        salesBlock,
        blockFlag,
        submitToSap,
      ];
}
