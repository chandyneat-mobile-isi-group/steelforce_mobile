import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_options_sheet.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_filter_header.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_stage_content.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_cart_footer.dart';

/// The product finder, assembled from the flow's reusable parts.
///
/// Layout is fixed and always in this order — search + filter, active filter
/// chips, then whichever stage the flow is on, then the cart summary. The
/// header never disappears: an experienced rep types a material code from the
/// category screen and gets products; a new rep walks the hierarchy. Both are
/// first-class, neither hides the other's entry point.
///
/// One widget serves both hosts (the standalone finder screen and the
/// quotation builder's product section) because it renders nothing but a
/// projection of [ProductFilterFlowState] plus the live [CartCubit], and
/// reports intent back as events. Set [sticky] when it owns the viewport.
class GuidedProductFilterView extends StatefulWidget {
  const GuidedProductFilterView({
    super.key,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onQuantityChanged,
    required this.quantityFor,
    this.lineTotalFor,
    this.onCustomize,
    this.onProductTap,
    this.onVoiceSearch,
    this.onImageSearch,
    this.onCartTap,
    this.sticky = true,
    this.depotId,
    this.leadId,
    this.onInputPrice,
    this.hostManualPriceFor,
  });

  final Set<String> favoriteIds;
  final ValueChanged<Product> onToggleFavorite;

  /// The single write path into the quotation. Zero means "remove this line".
  final void Function(Product product, int quantity) onQuantityChanged;

  /// Current cart quantity for a product, resolved by the host from
  /// [CartCubit] so this view never owns cart state.
  final int Function(Product product) quantityFor;

  final String Function(Product product, int quantity)? lineTotalFor;

  final ValueChanged<Product>? onCustomize;
  final ValueChanged<Product>? onProductTap;

  /// Alternative ways to produce the query. They resolve to text and feed the
  /// same search field, so voice and photo lookup stay first-class.
  final Future<String?> Function()? onVoiceSearch;
  final Future<String?> Function()? onImageSearch;

  final VoidCallback? onCartTap;

  final bool sticky;

  final String? depotId;
  final String? leadId;
  final Future<void> Function(Product product)? onInputPrice;
  final double? Function(Product product)? hostManualPriceFor;

  @override
  State<GuidedProductFilterView> createState() =>
      _GuidedProductFilterViewState();
}

class _GuidedProductFilterViewState extends State<GuidedProductFilterView> {
  /// The text field's own editing buffer, not flow state. The query that
  /// actually filters lives in [ProductFilterFlowState.query].
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ProductFilterFlowBloc get _bloc => context.read<ProductFilterFlowBloc>();

  Future<void> _applyResolvedQuery(Future<String?> Function() resolve) async {
    final query = await resolve();
    if (query == null || query.trim().isEmpty || !mounted) return;
    _searchController.text = query;
    _bloc.add(FilterProductSearchChanged(query));
  }

  Future<void> _openFilterSheet(ProductFilterFlowState state) async {
    final result = await showFilterOptionsSheet(
      context: context,
      sortBy: state.sortBy,
      availableOnly: state.availableOnly,
      selection: state.selection,
      categoryLabel: context.localizedOrNull(state.category?.name),
    );
    if (result == null || !mounted) return;

    if (result.clearAll) {
      _searchController.clear();
      _bloc.add(const FilterFlowReset());
      return;
    }
    _bloc.add(FilterPreferencesChanged(
      sortBy: result.sortBy,
      availableOnly: result.availableOnly,
    ));
    // Each cleared step is dispatched on its own so the bloc applies its own
    // dependency rules to every one of them.
    for (final stepKey in result.clearedStepKeys) {
      _bloc.add(FilterStepCleared(stepKey));
    }
  }

  void _findNewProduct() {
    _searchController.clear();
    _bloc.add(const FindNewProductRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductFilterFlowBloc, ProductFilterFlowState>(
      builder: (context, state) {
        final header = GuidedFilterHeader(
          state: state,
          searchController: _searchController,
          onSearchChanged: (value) =>
              _bloc.add(FilterProductSearchChanged(value)),
          onFilterTap: () => _openFilterSheet(state),
          onVoiceTap: widget.onVoiceSearch == null
              ? null
              : () => _applyResolvedQuery(widget.onVoiceSearch!),
          onImageTap: widget.onImageSearch == null
              ? null
              : () => _applyResolvedQuery(widget.onImageSearch!),
          onClearStep: (key) => _bloc.add(FilterStepCleared(key)),
          onClearCategory: () => _bloc.add(const FilterFlowReset()),
          onBack: () => _bloc.add(const FilterFlowBackRequested()),
        );

        final content = GuidedStageContent(
          state: state,
          favoriteIds: widget.favoriteIds,
          quantityFor: widget.quantityFor,
          lineTotalFor: widget.lineTotalFor,
          onQuantityChanged: widget.onQuantityChanged,
          onToggleFavorite: widget.onToggleFavorite,
          onCustomize: widget.onCustomize,
          onProductTap: widget.onProductTap,
          onFindNewProduct: _findNewProduct,
          depotId: widget.depotId,
          leadId: widget.leadId,
          onInputPrice: widget.onInputPrice,
          hostManualPriceFor: widget.hostManualPriceFor,
        );

        final footer = GuidedCartFooter(
          onTap: widget.onCartTap,
          onFindNewProduct: _findNewProduct,
          showFindNew: state.stage == FilterFlowStage.products,
        );

        if (!widget.sticky) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              SizedBox(height: context.rh(14)),
              content,
              SizedBox(height: context.rh(14)),
              footer,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: header,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: content,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: footer,
            ),
          ],
        );
      },
    );
  }
}
