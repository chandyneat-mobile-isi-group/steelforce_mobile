// The locally saved wizard form (`BpDepotDraft`) as JSON, and the
// server-owned draft fields applied back onto it.
//
// Deliberately NOT the wire payload. The registration mapper
// (`bp_draft_to_business_partner.dart`) drops everything SAP has no field for
// — `vatTin`, the contact person, the remark, the photographs. Persisting
// through it would mean a rep who resumed a saved form silently lost the four
// fields the form had just made them fill in.
//
// Keys are the same camelCase names [applyBpServerFields] reads, so one
// vocabulary covers both paths. The format is pinned by
// `test/features/depots/bp_draft_json_format_test.dart`: drafts already on
// devices must keep loading, so a key here is never renamed.

import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';

/// Applies the server-owned draft returned by `POST draft` and `POST update`.
/// The API field names are deliberately kept at the boundary; the form keeps
/// its more readable Flutter names.
void applyBpServerFields(BpDepotDraft draft, Map<String, dynamic> fields) {
  String stringValue(String key, [String fallback = '']) {
    final value = fields[key];
    return value == null ? fallback : value.toString();
  }

  String? nullableString(String key, [String? fallback]) {
    final value = fields[key];
    if (value == null || value.toString().isEmpty) return fallback;
    return value.toString();
  }

  draft.grouping =
      stringValue('accountGroup', stringValue('partnerGroup', draft.grouping));
  draft.title = stringValue('title', draft.title);
  draft.nameEn = stringValue('name1', draft.nameEn);
  draft.name2 = stringValue('name2', draft.name2);
  draft.nameKh = stringValue('name3', draft.nameKh);
  draft.searchTerm = stringValue('searchTerm1', draft.searchTerm);
  draft.searchTerm2 = stringValue('searchTerm2', draft.searchTerm2);
  draft.coName = stringValue('coName', draft.coName);
  draft.depotNumber = stringValue('depotNumber', draft.depotNumber);
  draft.street = stringValue('street', draft.street);
  draft.houseNumber = stringValue('houseNo', draft.houseNumber);
  if (fields.containsKey('city')) {
    draft.cityCode = nullableString('city', draft.cityCode);
  }
  if (fields.containsKey('district')) {
    draft.districtCode = nullableString('district', draft.districtCode);
  }
  if (fields.containsKey('commune')) {
    draft.communeCode = nullableString('commune', draft.communeCode);
  } else if (fields.containsKey('communeCode')) {
    draft.communeCode = nullableString('communeCode', draft.communeCode);
  }
  if (fields.containsKey('village')) {
    draft.villageCode = nullableString('village', draft.villageCode);
  } else if (fields.containsKey('villageCode')) {
    draft.villageCode = nullableString('villageCode', draft.villageCode);
  }
  draft.postalCode = stringValue('postalCode', draft.postalCode);
  draft.regionCode = stringValue('region', draft.regionCode);
  draft.language = stringValue('language', draft.language);
  draft.mobilePhone = stringValue('mobilePhone', draft.mobilePhone);
  draft.telephone = stringValue('telephone', draft.telephone);
  draft.telephoneSameAsMobile =
      draft.telephone.isEmpty || draft.telephone == draft.mobilePhone;
  draft.faxNumber = stringValue('faxNumber', draft.faxNumber);
  draft.contactPersonName =
      stringValue('contactPersonName', draft.contactPersonName);
  if (fields.containsKey('contactPersonRole')) {
    draft.contactPersonRole =
        nullableString('contactPersonRole', draft.contactPersonRole);
  }
  if (fields.containsKey('salesOrg')) {
    draft.salesOrg = nullableString('salesOrg', draft.salesOrg);
  }
  if (fields.containsKey('salesOffice')) {
    draft.salesOffice = nullableString('salesOffice', draft.salesOffice);
  }
  if (fields.containsKey('salesGroup')) {
    draft.salesGroupCode = nullableString('salesGroup', draft.salesGroupCode);
  }
  if (fields.containsKey('distributionChannel')) {
    draft.distributionChannel =
        nullableString('distributionChannel', draft.distributionChannel);
  }
  if (fields.containsKey('division')) {
    draft.divisionCode = nullableString('division', draft.divisionCode);
  }
  if (fields.containsKey('depotGroup')) {
    draft.depotGroup = nullableString('depotGroup', draft.depotGroup);
  }
  if (fields.containsKey('priceGroup')) {
    draft.priceGroup = nullableString('priceGroup', draft.priceGroup);
  }
  if (fields.containsKey('deliveryPriority')) {
    draft.deliveryPriority =
        nullableString('deliveryPriority', draft.deliveryPriority);
  }
  if (fields.containsKey('shippingCondition')) {
    draft.shippingCondition =
        nullableString('shippingCondition', draft.shippingCondition);
  }
  if (fields.containsKey('paymentTerms')) {
    draft.paymentTerm = nullableString('paymentTerms', draft.paymentTerm);
  }
  if (fields.containsKey('taxClass')) {
    draft.taxClass = nullableString('taxClass', draft.taxClass);
  }
  draft.vatTin = stringValue('vatTin', draft.vatTin);
  draft.currency = stringValue('currency', draft.currency);
  draft.remark = stringValue('remark', draft.remark);

  if (fields.containsKey('creditLimit')) {
    final rawCreditLimit = fields['creditLimit'];
    if (rawCreditLimit is num) {
      draft.creditLimit = rawCreditLimit.toDouble();
    } else if (rawCreditLimit is String && rawCreditLimit.isNotEmpty) {
      draft.creditLimit = double.tryParse(rawCreditLimit);
    }
  }

  final latitude = fields['latitude'];
  final longitude = fields['longitude'];
  if (latitude is num && longitude is num) {
    draft.geoFix = GeoFix(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      capturedAt: DateTime.now(),
    );
  }
}

/// The form as it is saved on the device.
Map<String, dynamic> bpDraftToJson(BpDepotDraft draft) => {
      'accountGroup': draft.grouping,
      'title': draft.title,
      'name1': draft.nameEn,
      'name2': draft.name2,
      'name3': draft.nameKh,
      'coName': draft.coName,
      'searchTerm1': draft.searchTerm,
      'searchTerm2': draft.searchTerm2,
      'depotNumber': draft.depotNumber,
      'street': draft.street,
      'houseNo': draft.houseNumber,
      'city': draft.cityCode,
      'district': draft.districtCode,
      'commune': draft.communeCode,
      'village': draft.villageCode,
      'postalCode': draft.postalCode,
      'region': draft.regionCode,
      'language': draft.language,
      'mobilePhone': draft.mobilePhone,
      'telephone': draft.telephone,
      'telephoneSameAsMobile': draft.telephoneSameAsMobile,
      'faxNumber': draft.faxNumber,
      'contactPersonName': draft.contactPersonName,
      'contactPersonRole': draft.contactPersonRole,
      'salesOrg': draft.salesOrg,
      'salesOffice': draft.salesOffice,
      'salesGroup': draft.salesGroupCode,
      'distributionChannel': draft.distributionChannel,
      'division': draft.divisionCode,
      'depotGroup': draft.depotGroup,
      'priceGroup': draft.priceGroup,
      'priceGroupOverridden': draft.priceGroupOverridden,
      'deliveryPriority': draft.deliveryPriority,
      'shippingCondition': draft.shippingCondition,
      'paymentTerms': draft.paymentTerm,
      'taxClass': draft.taxClass,
      'vatTin': draft.vatTin,
      'currency': draft.currency,
      if (draft.creditLimit != null) 'creditLimit': draft.creditLimit,
      if (draft.serverDepotId != null) 'serverDepotId': draft.serverDepotId,
      'isPendingHqApproval': draft.isPendingHqApproval,
      'remark': draft.remark,
      'latitude': draft.geoFix?.latitude,
      'longitude': draft.geoFix?.longitude,
      'attachments': draft.attachments
          .map((a) => {
                'kind': a.kind,
                'local_path': a.localPath,
                if (a.remoteUrl != null) 'url': a.remoteUrl,
                'is_uploaded': a.isUploaded,
                'captured_at': a.capturedAt.toIso8601String(),
              })
          .toList(),
    };

/// Rebuilds a saved form.
///
/// Reuses [applyBpServerFields] for the shared keys and then restores the
/// fields that only exist locally. The gazetteer `GeoAddress` is *not*
/// restored — only the four codes are, and `GeoLocationSelector` re-resolves
/// them from `initialCodes` on build. Persisting the resolved object would
/// pin a rep to a gazetteer revision that a later app version has corrected.
BpDepotDraft bpDraftFromJson(Map<String, dynamic> json) {
  final draft = BpDepotDraft();
  applyBpServerFields(draft, json);

  final sameAsMobile = json['telephoneSameAsMobile'];
  if (sameAsMobile is bool) draft.telephoneSameAsMobile = sameAsMobile;

  final overridden = json['priceGroupOverridden'];
  if (overridden is bool) draft.priceGroupOverridden = overridden;

  final serverCustId = json['serverDepotId']?.toString();
  if (serverCustId != null && serverCustId.isNotEmpty) {
    draft.serverDepotId = serverCustId;
  }
  draft.isPendingHqApproval = json['isPendingHqApproval'] == true;

  final attachments = json['attachments'];
  if (attachments is List) {
    for (final raw in attachments.whereType<Map>()) {
      final kind = raw['kind']?.toString();
      final path = raw['local_path']?.toString();
      if (kind == null || path == null || path.isEmpty) continue;
      final capturedAt = raw['captured_at']?.toString();
      draft.attachments.add(BpAttachment(
        kind: kind,
        localPath: path,
        remoteUrl: raw['url']?.toString(),
        isUploaded: raw['is_uploaded'] == true,
        capturedAt: capturedAt == null ? null : DateTime.tryParse(capturedAt),
      ));
    }
  }
  return draft;
}
