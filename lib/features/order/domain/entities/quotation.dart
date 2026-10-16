import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';

/// A draft pre-sales document built in the Quotation Builder. Either
/// shop-scoped ([depotId] set) or lead-scoped ([leadId] set) — never
/// both. Replaces the old `PendingOrder` end-to-end.
class Quotation extends Equatable {
  const Quotation({
    required this.id,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.status,
    required this.sapDraftStatus,
    required this.validUntil,
    required this.createdAt,
    required this.updatedAt,
    this.depotId,
    this.shopName,
    this.leadId,
    this.leadDisplayName,
    this.offVisitReason,
    this.gpsLatitude,
    this.gpsLongitude,
    this.remoteId,
  });

  final String id;
  final String? depotId;
  final String? shopName;
  final String? leadId;
  final String? leadDisplayName;
  final List<CartItem> lines;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final QuotationStatus status;
  final OffVisitReason? offVisitReason;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String sapDraftStatus;
  final DateTime validUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The Admin backend's id for this quotation, once the backend has one —
  /// either because the builder opened a server draft while online, or because
  /// the sync queue created it. Null means the backend has never seen it.
  final String? remoteId;

  bool get isLeadScoped => leadId != null;

  Quotation copyWith({
    List<CartItem>? lines,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    QuotationStatus? status,
    DateTime? updatedAt,
    String? Function()? remoteId,
  }) {
    return Quotation(
      id: id,
      depotId: depotId,
      shopName: shopName,
      leadId: leadId,
      leadDisplayName: leadDisplayName,
      lines: lines ?? this.lines,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      status: status ?? this.status,
      offVisitReason: offVisitReason,
      gpsLatitude: gpsLatitude,
      gpsLongitude: gpsLongitude,
      sapDraftStatus: sapDraftStatus,
      validUntil: validUntil,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteId: remoteId != null ? remoteId() : this.remoteId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        depotId,
        shopName,
        leadId,
        leadDisplayName,
        lines,
        subtotal,
        discount,
        tax,
        total,
        status,
        offVisitReason,
        gpsLatitude,
        gpsLongitude,
        sapDraftStatus,
        validUntil,
        createdAt,
        updatedAt,
        remoteId,
      ];
}
