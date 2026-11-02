import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';

/// The device's quotation store during practice: [OrderPracticeData] instead
/// of the encrypted `quotations` table.
///
/// Mirrors `QuotationRepositoryImpl`'s semantics — the same empty-cart
/// refusal, the same totals fallback, the same `saved` status — so a lesson
/// rehearses exactly what the real save does. Once [PracticeWorld.isClosed]
/// every call goes to [_real].
class PracticeQuotationRepository implements QuotationRepository {
  PracticeQuotationRepository({
    required QuotationRepository real,
    required PracticeWorld world,
    required OrderPracticeData data,
  })  : _real = real,
        _world = world,
        _data = data;

  final QuotationRepository _real;
  final PracticeWorld _world;
  final OrderPracticeData _data;

  bool get _live => _world.isClosed;

  static const _noItems =
      CacheFailure(message: 'orders.quotation.error.no_items');
  static const _notFound =
      CacheFailure(message: 'orders.quotation.error.not_found');

  @override
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
  }) async {
    if (_live) {
      return _real.saveQuotation(
        items: items,
        depotId: depotId,
        shopName: shopName,
        leadId: leadId,
        leadDisplayName: leadDisplayName,
        offVisitReason: offVisitReason,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        remoteId: remoteId,
      );
    }
    if (items.isEmpty) return const Failed(_noItems);

    final now = _data.now();
    final totals = _totals(items,
        subtotal: subtotal, discount: discount, tax: tax, total: total);
    final quotation = Quotation(
      id: _data.newId('${PracticeIds.quotationPrefix}local-'),
      depotId: depotId,
      shopName: shopName,
      leadId: leadId,
      leadDisplayName: leadDisplayName,
      lines: List.unmodifiable(items),
      subtotal: totals.subtotal,
      discount: totals.discount,
      tax: totals.tax,
      total: totals.total,
      status: QuotationStatus.saved,
      offVisitReason: offVisitReason,
      gpsLatitude: gpsLat,
      gpsLongitude: gpsLng,
      sapDraftStatus: 'Saved on device',
      validUntil: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
      remoteId: remoteId,
    );
    _data.quotations[quotation.id] = quotation;
    _data.quotationsChanged();
    return Success(quotation);
  }

  @override
  ResultFuture<Quotation> updateQuotation(
    Quotation existing, {
    required List<CartItem> items,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? remoteId,
  }) async {
    if (_live) {
      return _real.updateQuotation(existing,
          items: items,
          subtotal: subtotal,
          discount: discount,
          tax: tax,
          total: total,
          remoteId: remoteId);
    }
    if (items.isEmpty) return const Failed(_noItems);

    final totals = _totals(items,
        subtotal: subtotal, discount: discount, tax: tax, total: total);
    final updated = existing.copyWith(
      lines: List.unmodifiable(items),
      subtotal: totals.subtotal,
      discount: totals.discount,
      tax: totals.tax,
      total: totals.total,
      updatedAt: _data.now(),
      remoteId: remoteId == null ? null : () => remoteId,
    );
    _data.quotations[updated.id] = updated;
    _data.quotationsChanged();
    return Success(updated);
  }

  @override
  ResultFuture<void> linkRemote(String quotationId, String remoteId) async {
    if (_live) return _real.linkRemote(quotationId, remoteId);
    final existing = _data.quotations[quotationId];
    if (existing != null) {
      _data.quotations[quotationId] =
          existing.copyWith(remoteId: () => remoteId);
      _data.quotationsChanged();
    }
    return const Success(null);
  }

  @override
  ResultFuture<Quotation> markConverted(String quotationId) async {
    if (_live) return _real.markConverted(quotationId);
    final existing = _data.quotations[quotationId];
    if (existing == null) return const Failed(_notFound);
    final converted = existing.copyWith(
      status: QuotationStatus.converted,
      updatedAt: _data.now(),
    );
    _data.quotations[quotationId] = converted;
    _data.quotationsChanged();
    return Success(converted);
  }

  @override
  ResultFuture<Quotation?> getQuotationById(String id) async {
    if (_live) return _real.getQuotationById(id);
    return Success(_data.quotations[id]);
  }

  @override
  ResultFuture<void> deleteQuotation(String id) async {
    if (_live) return _real.deleteQuotation(id);
    _data.quotations.remove(id);
    _data.quotationsChanged();
    return const Success(null);
  }

  @override
  Stream<List<Quotation>> watchQuotations() async* {
    if (_live) {
      yield* _real.watchQuotations();
      return;
    }
    yield List.unmodifiable(_data.quotations.values);
    yield* _data.quotationChanges;
  }

  /// `QuotationRepositoryImpl`'s fallback arithmetic, verbatim.
  static ({double subtotal, double discount, double tax, double total}) _totals(
    List<CartItem> items, {
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
  }) {
    final s =
        subtotal ?? items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);
    final d =
        discount ?? items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
    final t = tax ?? ((s - d) * OrderPracticeData.taxRate);
    return (subtotal: s, discount: d, tax: t, total: total ?? (s - d + t));
  }
}
