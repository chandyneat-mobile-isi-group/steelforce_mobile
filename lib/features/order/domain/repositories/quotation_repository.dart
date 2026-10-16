import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';

abstract interface class QuotationRepository {
  ResultFuture<Quotation> saveQuotation({
    required List<CartItem> items,
    String? depotId,
    String? shopName,
    String? leadId,
    String? leadDisplayName,
    OffVisitReason? offVisitReason,
    double? gpsLat,
    double? gpsLng,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? remoteId,
  });

  ResultFuture<Quotation> updateQuotation(
    Quotation existing, {
    required List<CartItem> items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? remoteId,
  });

  /// Records the Admin backend's id for a local quotation, so every later push
  /// reuses that document instead of opening a new one.
  ResultFuture<void> linkRemote(String quotationId, String remoteId);

  ResultFuture<Quotation> markConverted(String quotationId);

  ResultFuture<Quotation?> getQuotationById(String id);

  /// Permanently removes a draft quotation (user discarded it).
  ResultFuture<void> deleteQuotation(String id);

  /// Live stream of saved quotations — emits the current list on listen,
  /// then re-emits after every save/update/conversion.
  Stream<List<Quotation>> watchQuotations();
}
