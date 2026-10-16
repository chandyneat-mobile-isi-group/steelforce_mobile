import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';

/// The "no order" reasons for check-out (`check-in-check-out-mobile.md` §6).
abstract interface class CheckOutReasonRepository {
  /// The server's list when online, else the cached one. Never empty and
  /// never fails: `other` is always offered, so a rep is never stuck unable
  /// to close a visit.
  Future<List<NoOrderReason>> getReasons();
}
