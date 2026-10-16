import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';

/// Supplies the signed-in rep's identity for a registration.
///
/// `salesEmployeeId` becomes `PersonnelNumber` on the payload, so it must be
/// the personnel number of **the rep who is signed in** — never a constant.
/// A fixed number used to be wired here, which stamped every registration from
/// every rep against one person's record.
///
/// Returns null when there is no trustworthy identity. Callers must refuse to
/// send in that case rather than substitute a value: a wrong personnel number
/// is accepted by the backend and then misattributes the shop.
abstract interface class RepSalesContextSource {
  Future<RepSalesContext?> current();
}
