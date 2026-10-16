import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/credit_summary.dart';

/// Mocked stand-in for an online SAP credit-position lookup — same
/// structural separation as `MtoPricingService`: never resolved from local
/// cache, always a fresh (simulated) request.
abstract interface class CreditService {
  ResultFuture<CreditSummary> getSummary(String depotId);
}
