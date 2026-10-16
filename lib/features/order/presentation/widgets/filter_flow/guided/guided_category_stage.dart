import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/category_selector.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/empty_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/loading_products.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/filter_stage_header.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/filter_failure_state.dart';

class GuidedCategoryStage extends StatelessWidget {
  const GuidedCategoryStage({super.key, required this.state});
  final ProductFilterFlowState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == FilterFlowStatus.loading) {
      return LoadingProducts.grid(count: 6);
    }
    if (state.status == FilterFlowStatus.failure) {
      return FilterFailureState(message: state.errorMessage);
    }
    if (state.categories.isEmpty) {
      return EmptyProducts.chooseCategory(
        title: 'orders.guided_filter.no_categories_title'.tr,
        message: 'orders.guided_filter.no_categories_message'.tr,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterStageHeader(
          title: 'orders.guided_filter.choose_category'.tr,
          subtitle: 'orders.guided_filter.choose_category_hint'.tr,
        ),
        SizedBox(height: context.rh(12)),
        CategorySelector(
          categories: state.categories,
          selectedCategoryId: state.category?.code,
          onSelect: (category) => context
              .read<ProductFilterFlowBloc>()
              .add(FilterCategorySelected(category)),
        ),
      ],
    );
  }
}
