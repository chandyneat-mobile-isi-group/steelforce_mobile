import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';

/// Per-step validation for the registration wizard.
extension BpDepotDraftValidation on BpDepotDraft {
  // ---------------------------------------------------------------------
  // Per-step validation. Returns field-key -> i18n error key.
  // The UI blocks "Next" while the map is non-empty.
  // ---------------------------------------------------------------------
  Map<String, String> validateStep(BpFormStep step) {
    final e = <String, String>{};

    switch (step) {
      case BpFormStep.identity:
        if (grouping.isEmpty) e['grouping'] = 'error.required';
        if (title.isEmpty) e['title'] = 'error.required';
        if (nameEn.trim().isEmpty) {
          e['nameEn'] = 'error.required';
        } else if (nameEn.trim().length > 40) {
          e['nameEn'] = 'error.max_40'; // SAP NAME1 is 40 chars
        }
        if (nameKh.trim().isEmpty) {
          e['nameKh'] = 'error.required';
        } else if (!hasKhmerName) {
          e['nameKh'] = 'error.must_be_khmer';
        }
        break;

      case BpFormStep.address:
        if (cityCode == null || cityCode!.isEmpty) e['city'] = 'error.required';
        if (districtCode == null || districtCode!.isEmpty) {
          e['district'] = 'error.required';
        }
        if ((communeCode == null || communeCode!.isEmpty) &&
            geoAddress?.commune == null) {
          e['commune'] = 'error.required';
        }
        // Six digits is the current Cambodia Post scheme and what the
        // gazetteer supplies. Five is still accepted because a rep may be
        // editing a draft saved under the superseded scheme, and rejecting
        // their own stored value would strand them on this step.
        if (!RegExp(r'^\d{5,6}$').hasMatch(postalCode.trim())) {
          e['postalCode'] = 'error.postal_code';
        }
        if (geoFix == null) {
          e['geo'] = 'error.gps_required';
        } else if (!geoFix!.isInsideCambodia) {
          e['geo'] = 'error.gps_outside_kh';
        }
        break;

      case BpFormStep.contact:
        if (mobilePhone.trim().isEmpty) e['mobilePhone'] = 'error.required';
        if (!telephoneSameAsMobile && telephone.trim().isEmpty) {
          e['telephone'] = 'error.required';
        }
        if (contactPersonName.trim().isEmpty) {
          e['contactPersonName'] = 'error.required';
        }
        if (contactPersonRole == null) {
          e['contactPersonRole'] = 'error.required';
        }
        break;

      case BpFormStep.salesTerms:
        // Treated as required even though the server accepts them absent: a
        // record missing the sales area saves happily and can then never be
        // delivered to SAP, which is worse than a validation error the rep can
        // fix while still standing in the shop.
        if (salesOrg == null) e['salesOrg'] = 'error.required';
        if (salesOffice == null) e['salesOffice'] = 'error.required';
        if (salesGroupCode == null) e['salesGroup'] = 'error.required';
        if (distributionChannel == null) {
          e['distributionChannel'] = 'error.required';
        }
        if (divisionCode == null) e['division'] = 'error.required';
        if (depotGroup == null) e['depotGroup'] = 'error.required';
        if (deliveryPriority == null) e['deliveryPriority'] = 'error.required';
        if (shippingCondition == null) {
          e['shippingCondition'] = 'error.required';
        }
        if (paymentTerm == null) e['paymentTerm'] = 'error.required';
        if (taxClass == null) {
          e['taxClass'] = 'error.required';
        } else if (taxClass == '1' && vatTin.trim().isEmpty) {
          e['vatTin'] = 'error.vat_tin_required';
        }
        break;

      case BpFormStep.documents:
        if (!hasAttachment('outlet_front')) {
          e['outlet_front'] = 'error.photo_required';
        }
        if (!hasAttachment('outlet_inside')) {
          e['outlet_inside'] = 'error.photo_required';
        }
        if (!hasAttachment('id_card')) {
          e['id_card'] = 'error.photo_required';
        }
        if (taxClass == '1' && !hasAttachment('vat_cert')) {
          e['vat_cert'] = 'error.photo_required';
        }
        break;

      case BpFormStep.review:
        // No specific validation on the review step itself.
        break;
    }
    return e;
  }

  bool isStepComplete(BpFormStep step) => validateStep(step).isEmpty;

  bool get isReadyToSubmit => BpFormStep.values.every(isStepComplete);
}
