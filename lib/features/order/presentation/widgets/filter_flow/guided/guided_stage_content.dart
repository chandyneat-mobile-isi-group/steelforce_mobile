import 'dart:async';
import 'package:flutter/material.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/filter_flow_transition.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_category_stage.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_step_stage.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/guided_product_stage.dart';

class GuidedStageContent extends StatelessWidget {
  const GuidedStageContent({
    super.key,
    required this.state,
    required this.favoriteIds,
    required this.quantityFor,
    required this.lineTotalFor,
    required this.onQuantityChanged,
    required this.onToggleFavorite,
    required this.onCustomize,
    required this.onProductTap,
    required this.onFindNewProduct,
    this.depotId,
    this.leadId,
    this.onInputPrice,
    this.hostManualPriceFor,
  });

  final ProductFilterFlowState state;
  final Set<String> favoriteIds;
  final int Function(Product product) quantityFor;
  final String Function(Product product, int quantity)? lineTotalFor;
  final void Function(Product product, int quantity) onQuantityChanged;
  final ValueChanged<Product> onToggleFavorite;
  final ValueChanged<Product>? onCustomize;
  final ValueChanged<Product>? onProductTap;
  final VoidCallback onFindNewProduct;
  final String? depotId;
  final String? leadId;
  final Future<void> Function(Product product)? onInputPrice;
  final double? Function(Product product)? hostManualPriceFor;

  @override
  Widget build(BuildContext context) {
    return FilterFlowTransition(
      stageKey: _stageKey,
      child: switch (state.stage) {
        FilterFlowStage.categories => GuidedCategoryStage(state: state),
        FilterFlowStage.steps => GuidedStepStage(state: state),
        FilterFlowStage.products => GuidedProductStage(
            state: state,
            favoriteIds: favoriteIds,
            quantityFor: quantityFor,
            lineTotalFor: lineTotalFor,
            onQuantityChanged: onQuantityChanged,
            onToggleFavorite: onToggleFavorite,
            onCustomize: onCustomize,
            onProductTap: onProductTap,
            onFindNewProduct: onFindNewProduct,
            depotId: depotId,
            leadId: leadId,
            onInputPrice: onInputPrice,
            hostManualPriceFor: hostManualPriceFor,
          ),
      },
    );
  }

  /// Keyed on stage identity, not data: re-running the query after a keystroke
  /// must not replay the slide-in.
  Object get _stageKey => switch (state.stage) {
        FilterFlowStage.categories => 'categories',
        FilterFlowStage.steps => 'step:${state.activeStep?.key}',
        FilterFlowStage.products =>
          'products:${state.category?.code}:${state.hasSearch}',
      };
}
