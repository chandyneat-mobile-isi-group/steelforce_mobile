/// Sales-area context of the logged-in rep. Injected from the auth/session
/// layer — the rep never types these.
class RepSalesContext {
  final String salesOrganization; // 0001 - PhnomPenh ISI
  final String salesOrganizationName;
  final String salesOffice; // 0001 - Phnom Penh
  final String salesOfficeName;
  final String salesEmployeeId; // 107576
  final String salesEmployeeName; // Mengchou CHORN
  final String defaultCurrency; // USD

  const RepSalesContext({
    required this.salesOrganization,
    required this.salesOrganizationName,
    required this.salesOffice,
    required this.salesOfficeName,
    required this.salesEmployeeId,
    required this.salesEmployeeName,
    this.defaultCurrency = 'USD',
  });
}
