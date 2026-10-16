import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/catalog_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/catalog_event.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/catalog_state.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/stock_cubit.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/catalog_skeletons.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/product_card.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The SAP material number for a product.
///
/// `/materials/{material}/stock` is keyed on SAP's number, which is not the
/// platform row id. `code` is the field carrying it on this screen — if that
/// stops being true, this is the one line to change, and
/// [ProductListSection.materialNumberOf] overrides it per caller.
String _defaultMaterialNumber(Product product) => product.code;

class ProductListSection extends StatelessWidget {
  const ProductListSection({
    super.key,
    required this.state,
    required this.favoriteIds,
    required this.expandedProductId,
    required this.leadId,
    required this.depotId,
    required this.onToggleFavorite,
    required this.onToggleExpanded,
    this.onCustomize,
    this.height,
    this.hasActiveAttributeFilter = false,
    this.quantity = 1,
    this.unit,
    this.materialNumberOf = _defaultMaterialNumber,
  });

  final CatalogState state;
  final Set<String> favoriteIds;
  final String? expandedProductId;
  final String? leadId;
  final String? depotId;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onToggleExpanded;

  /// Opens the category-aware customization form for a product. When null, the
  /// per-card customize action is hidden.
  final ValueChanged<Product>? onCustomize;
  final double? height;
  final bool hasActiveAttributeFilter;
  final double quantity;
  final String? unit;

  /// How to get SAP's material number out of a [Product].
  final String Function(Product product) materialNumberOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return switch (state) {
      CatalogIdle() || CatalogLoading() => const CatalogGridSkeleton(),
      CatalogError(:final message) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child: Text(message,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6)))),
        ),
      CatalogLoaded(:final items, :final hasMore, :final isLoadingMore) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Products',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.rsp(14),
                      color: scheme.onSurface),
                ),
                if (hasActiveAttributeFilter) ...[
                  SizedBox(width: context.rw(8)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'orders.filter.match_count'
                          .trParams({'count': items.length}),
                      style: TextStyle(
                          color: scheme.primary,
                          fontSize: context.rsp(11),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: context.rh(8)),
            SizedBox(
              height: height ?? context.rh(200),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            hasActiveAttributeFilter
                                ? 'orders.filter.no_match_combo'.tr
                                : 'orders.catalog.no_products'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ),
                      )
                    else
                      // Scoped to the rows so a verdict landing for one
                      // material does not rebuild the header and the paging
                      // controls with it.
                      BlocBuilder<StockCubit,
                          Map<String, MaterialAvailability>>(
                        builder: (context, stock) => Column(
                          children: [
                            for (final product in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ProductRow(
                                  product: product,
                                  material: materialNumberOf(product),
                                  stock: stock[materialNumberOf(product)],
                                  isFavorite: favoriteIds.contains(product.id),
                                  onToggleFavorite: onToggleFavorite,
                                  onToggleExpanded: onToggleExpanded,
                                  onCustomize: onCustomize,
                                  quantity: quantity,
                                  unit: unit,
                                  leadId: leadId,
                                  depotId: depotId,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (hasMore)
                      Center(
                        child: isLoadingMore
                            ? Padding(
                                padding: EdgeInsets.all(context.rr(16)),
                                child: CircularProgressIndicator(
                                    color: scheme.primary),
                              )
                            : TextButton(
                                onPressed: () => context
                                    .read<CatalogBloc>()
                                    .add(const CatalogLoadMoreRequested()),
                                child: Text('orders.catalog.load_more'.tr),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
    };
  }
}

/// One row, and the decision about **when** the stock question gets asked.
///
/// Not on build: a list of forty materials would mean forty live ERP round
/// trips for a rep who is only scrolling. Not only on add-to-cart either — by
/// then the rep has already committed and the badge is arriving too late to
/// inform the decision.
///
/// So: on the gestures that mean the rep has singled this material out —
/// opening the row, customizing it, or adding it. [StockCubit.ensure] is
/// idempotent and holds a verdict for five minutes, so repeating a gesture
/// costs nothing.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.material,
    required this.stock,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onToggleExpanded,
    required this.onCustomize,
    required this.quantity,
    required this.unit,
    required this.leadId,
    required this.depotId,
  });

  final Product product;
  final String material;
  final MaterialAvailability? stock;
  final bool isFavorite;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<Product>? onCustomize;
  final double quantity;
  final String? unit;
  final String? leadId;
  final String? depotId;

  @override
  Widget build(BuildContext context) {
    void ask() => context.read<StockCubit>().ensure(material);

    return ProductCard(
      product: product,
      isFavorite: isFavorite,
      onFavoriteToggle: () => onToggleFavorite(product.id),
      onTap: () {
        ask();
        onToggleExpanded(product.id);
      },
      onAddToCart: () {
        // The stock read still fires — other parts of the flow use it — but it
        // no longer gates the add. Material selection is independent of stock:
        // a rep may put any catalogue material on a quotation, and SAP's
        // verdict is settled later rather than at the point of choosing.
        ask();
        context.read<CartCubit>().addProduct(
              product,
              quantity: quantity,
              unit: unit,
              leadId: leadId,
              depotId: depotId,
            );
      },
      onCustomize: onCustomize == null
          ? null
          : () {
              ask();
              onCustomize!(product);
            },
    );
  }
}
