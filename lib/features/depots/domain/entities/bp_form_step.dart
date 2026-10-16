/// The six capture steps of the "Add Depot" bottom sheet.
enum BpFormStep {
  identity, // 1. Who is the depot          (BP header + names)
  address, // 2. Where are they                (standard address + GPS)
  contact, // 3. How do we reach them          (phones + contact person)
  salesTerms, // 4. How do we sell to them     (sales area + billing/tax)
  documents, // 5. Proof                       (photos)
  review, // 6. Review                         (submit)
}

extension BpFormStepX on BpFormStep {
  int get number => index + 1;

  String get titleKey => switch (this) {
        BpFormStep.identity => 'add_depot.steps.identity',
        BpFormStep.address => 'add_depot.steps.address',
        BpFormStep.contact => 'add_depot.steps.contact',
        BpFormStep.salesTerms => 'add_depot.steps.sales_terms',
        BpFormStep.documents => 'add_depot.steps.documents',
        BpFormStep.review => 'add_depot.review',
      };
}
