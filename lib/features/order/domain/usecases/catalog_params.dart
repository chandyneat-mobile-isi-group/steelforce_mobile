import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/price_tier.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';

class ProductIdParams extends Equatable {
  const ProductIdParams(this.productId);
  final String productId;
  @override
  List<Object?> get props => [productId];
}

class BarcodeParams extends Equatable {
  const BarcodeParams(this.barcode);
  final String barcode;
  @override
  List<Object?> get props => [barcode];
}

class BrowseProductsParams extends Equatable {
  const BrowseProductsParams({
    required this.page,
    required this.pageSize,
    this.query = '',
    this.filter = const ProductFilter(),
  });

  final int page;
  final int pageSize;
  final String query;
  final ProductFilter filter;

  @override
  List<Object?> get props => [page, pageSize, query, filter];
}

class CategoryPageParams extends Equatable {
  const CategoryPageParams(
      {required this.categoryId, required this.page, required this.pageSize});
  final String categoryId;
  final int page;
  final int pageSize;
  @override
  List<Object?> get props => [categoryId, page, pageSize];
}

class FamilyIdParams extends Equatable {
  const FamilyIdParams(this.familyId);
  final String familyId;
  @override
  List<Object?> get props => [familyId];
}

class ProductCodeParams extends Equatable {
  const ProductCodeParams(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

class PricingParams extends Equatable {
  const PricingParams({required this.productId, required this.tier});
  final String productId;
  final PriceTier tier;
  @override
  List<Object?> get props => [productId, tier];
}

class CartItemIdParams extends Equatable {
  const CartItemIdParams(this.cartItemId);
  final String cartItemId;
  @override
  List<Object?> get props => [cartItemId];
}

class ReplaceCartParams extends Equatable {
  const ReplaceCartParams({required this.items, this.editingQuotationId});
  final List<CartItem> items;
  final String? editingQuotationId;
  @override
  List<Object?> get props => [items, editingQuotationId];
}

class SaveQuotationParams extends Equatable {
  const SaveQuotationParams({
    required this.items,
    this.depotId,
    this.shopName,
    this.leadId,
    this.leadDisplayName,
    this.offVisitReason,
    this.gpsLat,
    this.gpsLng,
    this.subtotal,
    this.discount,
    this.tax,
    this.total,
    this.remoteId,
  });
  final List<CartItem> items;
  final String? depotId;
  final String? shopName;
  final String? leadId;
  final String? leadDisplayName;
  final OffVisitReason? offVisitReason;
  final double? gpsLat;
  final double? gpsLng;
  final double? subtotal;
  final double? discount;
  final double? tax;
  final double? total;

  /// The backend draft the builder was editing, when it had one.
  final String? remoteId;
  @override
  List<Object?> get props => [
        items,
        depotId,
        shopName,
        leadId,
        leadDisplayName,
        offVisitReason,
        gpsLat,
        gpsLng,
        subtotal,
        discount,
        tax,
        total,
        remoteId,
      ];
}

class UpdateQuotationParams extends Equatable {
  const UpdateQuotationParams({
    required this.existing,
    required this.items,
    this.subtotal,
    this.discount,
    this.tax,
    this.total,
    this.remoteId,
  });
  final Quotation existing;
  final List<CartItem> items;
  final double? subtotal;
  final double? discount;
  final double? tax;
  final double? total;

  /// Set when the builder opened (or reopened) a backend draft for this
  /// quotation; null keeps whatever link [existing] already has.
  final String? remoteId;
  @override
  List<Object?> get props =>
      [existing, items, subtotal, discount, tax, total, remoteId];
}

class QuotationIdParams extends Equatable {
  const QuotationIdParams(this.quotationId);
  final String quotationId;
  @override
  List<Object?> get props => [quotationId];
}

class CreateSalesOrderParams extends Equatable {
  const CreateSalesOrderParams({required this.quotation, required this.items});
  final Quotation quotation;
  final List<CartItem> items;
  @override
  List<Object?> get props => [quotation, items];
}

class SalesOrderIdParams extends Equatable {
  const SalesOrderIdParams(this.salesOrderId);
  final String salesOrderId;
  @override
  List<Object?> get props => [salesOrderId];
}

class GetCreditSummaryParams extends Equatable {
  const GetCreditSummaryParams(this.depotId);
  final String depotId;
  @override
  List<Object?> get props => [depotId];
}
