import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/sap_option.dart';

// -----------------------------------------------------------------------------
// CONST — hard-coded at frontend. Never rendered as an input.
// -----------------------------------------------------------------------------
class SapBpConst {
  static const String partnerCategory = '2'; // Organization
  static const String bpRole = 'ZFLCU1'; // Depot
  static const String country = 'KH'; // Cambodia
  static const String departureCountry = 'KH';
  static const String region = 'R01'; // Central Area
  static const String timeZone = 'UTC+7';
  static const String salesOrg = '0001'; // Phnom Penh (ISI)
  static const String salesOffice = '0001'; // Phnom Penh
  static const String salesGroup = '010'; // Channel Sales
  static const String pricingProcedure = '1'; // Standard
  static const String taxCategory = 'MWST';
  static const String partnerFunction = 'VE'; // Sales Employee
  static const String creditControlArea = 'ISI';
  static const String companyCode = 'ISI';
  static const String defaultLanguage = 'EN';

  /// `T014` — 14 day due net. Business default for every new depot; the rep
  /// can still change it under "Adjust defaults".
  static const String defaultPaymentTerm = 'T014';

  /// Sent on every registration. Reps no longer pick a credit limit: HQ sets
  /// it in SAP after approval.
  static const String creditLimit = '0.00';

  /// The contact person's role on step 3. The English label is what SAP
  /// receives, inside `CoName` (see [BpDepotDraft.contactCoName]).
  static const List<SapOption> contactRoles = [
    SapOption('owner', 'Owner'),
    SapOption('manager', 'Manager'),
    SapOption('buyer', 'Buyer'),
    SapOption('accountant', 'Accountant'),
  ];

  /// SAP `NAME_CO` is 40 characters.
  static const int coNameMaxLength = 40;

  const SapBpConst._();
}
