import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';

/// Puts the server's per-field refusals back on the wizard's own fields.
///
/// The server keys errors by its contract paths (`address.districtCode`,
/// `salesAreas[0].salesOrg`); the form keys them by its widget names
/// (`district`, `salesOrg`). A path with no form field lands on the review
/// step's banner instead of being dropped.
abstract final class DepotDraftFieldErrors {
  static const Map<String, (String, BpFormStep)> _byPath = {
    'depotType': ('registrationType', BpFormStep.identity),
    'depots': ('supplyingDepots', BpFormStep.identity),
    'nameEn': ('nameEn', BpFormStep.identity),
    'nameKh': ('nameKh', BpFormStep.identity),
    'searchTerm1': ('searchTerm', BpFormStep.identity),
    'searchTerm2': ('searchTerm2', BpFormStep.identity),
    'address.provinceCode': ('city', BpFormStep.address),
    'address.districtCode': ('district', BpFormStep.address),
    'address.communeCode': ('commune', BpFormStep.address),
    'address.villageCode': ('village', BpFormStep.address),
    'address.street': ('street', BpFormStep.address),
    'location': ('geo', BpFormStep.address),
    'telephone': ('telephone', BpFormStep.contact),
    'mobilePhone': ('mobilePhone', BpFormStep.contact),
    'faxNumber': ('faxNumber', BpFormStep.contact),
    'contacts': ('contactPersonName', BpFormStep.contact),
    'name': ('contactPersonName', BpFormStep.contact),
    'role': ('contactPersonRole', BpFormStep.contact),
    'phoneNumber': ('mobilePhone', BpFormStep.contact),
    'salesAreas': ('salesOrg', BpFormStep.salesTerms),
    'salesOrg': ('salesOrg', BpFormStep.salesTerms),
    'distributionChannel': ('distributionChannel', BpFormStep.salesTerms),
    'division': ('division', BpFormStep.salesTerms),
    'customerGroup': ('depotGroup', BpFormStep.salesTerms),
    'salesOffice': ('salesOffice', BpFormStep.salesTerms),
    'shippingCondition': ('shippingCondition', BpFormStep.salesTerms),
    'paymentTerms': ('paymentTerm', BpFormStep.salesTerms),
    'creditLimit': ('creditLimit', BpFormStep.salesTerms),
  };

  /// Form field → the server's first message for it, plus the earliest step
  /// that owns one of them.
  static (Map<String, String>, BpFormStep?) map(
    Map<String, List<String>> serverErrors, {
    bool telephoneIsMobile = false,
  }) {
    final errors = <String, String>{};
    BpFormStep? step;
    for (final entry in serverErrors.entries) {
      final target = _byPath[entry.key] ?? _byPath[_leaf(entry.key)];
      if (target == null) continue;
      var (field, owner) = target;
      // The landline mirrors the mobile, so its error belongs on the mobile.
      if (field == 'telephone' && telephoneIsMobile) field = 'mobilePhone';
      errors[field] =
          entry.value.isEmpty ? 'error.required' : entry.value.first;
      if (step == null || owner.index < step.index) step = owner;
    }
    return (errors, step);
  }

  /// `salesAreas[0].salesOrg` → `salesOrg`; `contacts[0].name` → `name`.
  static String _leaf(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0
        ? path.replaceAll(RegExp(r'\[\d+\]'), '')
        : path.substring(dot + 1);
  }
}
