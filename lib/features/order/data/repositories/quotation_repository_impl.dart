import 'dart:async';
import 'dart:math';

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/order_line_codec.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/data/local/quotation_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';

const _validityDays = 14;

/// Composes [QuotationLocalDataSource] (`quotations` table) with
/// [ProductLocalDataSource] to rehydrate full [CartItem] lines — same shape
/// `CartRepositoryImpl` uses for its own rows.
class QuotationRepositoryImpl implements QuotationRepository {
  QuotationRepositoryImpl(
      {required QuotationLocalDataSource local,
      required ProductLocalDataSource productLocal})
      : _local = local,
        _lines = OrderLineCodec(productLocal);

  final QuotationLocalDataSource _local;

  /// Shared with [SalesOrderRepositoryImpl] so a quotation and the sales order
  /// it becomes can never disagree about what a line contains.
  final OrderLineCodec _lines;

  final StreamController<List<Quotation>> _controller =
      StreamController<List<Quotation>>.broadcast();

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
    try {
      if (items.isEmpty) {
        return const Failed(CacheFailure(message: 'Quotation has no items.'));
      }
      final now = DateTime.now();
      final calcSubtotal =
          subtotal ?? items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);
      final calcDiscount =
          discount ?? items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
      final calcTax = tax ?? ((calcSubtotal - calcDiscount) * 0.10);
      final calcTotal = total ?? (calcSubtotal - calcDiscount + calcTax);

      final quotation = Quotation(
        id: _newId('QT'),
        depotId: depotId,
        shopName: shopName,
        leadId: leadId,
        leadDisplayName: leadDisplayName,
        lines: items,
        subtotal: calcSubtotal,
        discount: calcDiscount,
        tax: calcTax,
        total: calcTotal,
        status: QuotationStatus.saved,
        offVisitReason: offVisitReason,
        gpsLatitude: gpsLat,
        gpsLongitude: gpsLng,
        // Legacy column, kept for the row shape. The app never saves to SAP.
        sapDraftStatus: 'Saved on device',
        validUntil: now.add(const Duration(days: _validityDays)),
        createdAt: now,
        updatedAt: now,
        remoteId: remoteId,
      );

      await _local.insertQuotation(_toRow(quotation));
      unawaited(_broadcast());
      return Success(quotation);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
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
    try {
      if (items.isEmpty) {
        return const Failed(CacheFailure(message: 'Quotation has no items.'));
      }
      final calcSubtotal =
          subtotal ?? items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);
      final calcDiscount =
          discount ?? items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
      final calcTax = tax ?? ((calcSubtotal - calcDiscount) * 0.10);
      final calcTotal = total ?? (calcSubtotal - calcDiscount + calcTax);

      final updated = existing.copyWith(
        lines: items,
        subtotal: calcSubtotal,
        discount: calcDiscount,
        tax: calcTax,
        total: calcTotal,
        updatedAt: DateTime.now(),
        remoteId: remoteId == null ? null : () => remoteId,
      );

      await _local.updateQuotation(_toRow(updated));
      unawaited(_broadcast());
      return Success(updated);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Quotation> markConverted(String quotationId) async {
    try {
      final row = await _local.getById(quotationId);
      if (row == null) {
        return const Failed(CacheFailure(message: 'Quotation not found.'));
      }
      final quotation = await _fromRow(row);
      final converted = quotation.copyWith(
        status: QuotationStatus.converted,
        updatedAt: DateTime.now(),
      );
      await _local.updateQuotation(_toRow(converted));
      unawaited(_broadcast());
      return Success(converted);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> linkRemote(String quotationId, String remoteId) async {
    try {
      await _local.updateQuotation({'id': quotationId, 'remote_id': remoteId});
      unawaited(_broadcast());
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<Quotation?> getQuotationById(String id) async {
    try {
      final row = await _local.getById(id);
      return Success(row == null ? null : await _fromRow(row));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<void> deleteQuotation(String id) async {
    try {
      await _local.deleteQuotation(id);
      await _broadcast();
      return const Success(null);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  Stream<List<Quotation>> watchQuotations() async* {
    yield await _loadAll();
    yield* _controller.stream;
  }

  Future<void> _broadcast() async {
    if (!_controller.hasListener) return;
    try {
      _controller.add(await _loadAll());
    } on CacheException {
      // Keep the last good list on a transient read error.
    }
  }

  Future<List<Quotation>> _loadAll() async {
    final rows = await _local.fetchAll();
    return Future.wait(rows.map(_fromRow));
  }

  DataMap _toRow(Quotation q) => {
        'id': q.id,
        'depot_id': q.depotId,
        'shop_name': q.shopName,
        'lead_id': q.leadId,
        'lead_display_name': q.leadDisplayName,
        'lines_json': _encodeLines(q.lines),
        'subtotal': q.subtotal,
        'discount': q.discount,
        'tax': q.tax,
        'total': q.total,
        'status': q.status.name,
        'off_visit_reason': q.offVisitReason?.name,
        'gps_lat': q.gpsLatitude,
        'gps_lng': q.gpsLongitude,
        'sap_draft_status': q.sapDraftStatus,
        'remote_id': q.remoteId,
        'valid_until': q.validUntil.toIso8601String(),
        'created_at': q.createdAt.toIso8601String(),
        'updated_at': q.updatedAt.toIso8601String(),
      };

  Future<Quotation> _fromRow(DataMap row) async {
    return Quotation(
      id: row['id'] as String,
      depotId: row['depot_id'] as String?,
      shopName: row['shop_name'] as String?,
      leadId: row['lead_id'] as String?,
      leadDisplayName: row['lead_display_name'] as String?,
      lines: await _decodeLines(row['lines_json'] as String,
          depotId: row['depot_id'] as String?,
          leadId: row['lead_id'] as String?),
      subtotal: (row['subtotal'] as num).toDouble(),
      discount: (row['discount'] as num).toDouble(),
      tax: (row['tax'] as num).toDouble(),
      total: (row['total'] as num).toDouble(),
      status: QuotationStatus.values.firstWhere((s) => s.name == row['status']),
      offVisitReason: row['off_visit_reason'] == null
          ? null
          : OffVisitReason.values
              .firstWhere((r) => r.name == row['off_visit_reason']),
      gpsLatitude: (row['gps_lat'] as num?)?.toDouble(),
      gpsLongitude: (row['gps_lng'] as num?)?.toDouble(),
      sapDraftStatus: row['sap_draft_status'] as String,
      validUntil: DateTime.parse(row['valid_until'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      remoteId: row['remote_id'] as String?,
    );
  }

  String _encodeLines(List<CartItem> items) => _lines.encode(items);

  Future<List<CartItem>> _decodeLines(String json,
          {String? depotId, String? leadId}) =>
      _lines.decode(json, depotId: depotId, leadId: leadId);

  /// Local ids used to be `% 1000000` of the clock — a million-value space
  /// that wraps every second, so two quotations saved a second apart could
  /// share an id and the second `INSERT OR REPLACE` silently overwrote the
  /// first. Full microseconds plus a random suffix cannot collide on one
  /// device in practice.
  static final Random _random = Random.secure();
  static String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(0x7fffffff).toRadixString(36)}';
}
