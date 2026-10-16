import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_step.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/dynamic_filter_section.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/empty_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/loading_products.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/product_family_selector.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided/filter_stage_header.dart';

class GuidedStepStage extends StatelessWidget {
  const GuidedStepStage({super.key, required this.state});
  final ProductFilterFlowState state;

  @override
  Widget build(BuildContext context) {
    final step = state.activeStep;
    if (step == null) return const SizedBox.shrink();

    final bloc = context.read<ProductFilterFlowBloc>();
    void select(FilterOption option) =>
        bloc.add(FilterStepAnswered(stepKey: step.key, option: option));

    final Widget selector;
    if (state.optionsLoading) {
      selector = step.role == FilterStepRole.family
          ? LoadingProducts.list()
          : (step.style == FilterStepStyle.grid
              ? LoadingProducts.grid()
              : LoadingProducts.chips());
    } else if (state.activeOptions.isEmpty) {
      selector = EmptyProducts.chooseFamily(
        title: 'orders.guided_filter.no_options_title'
            .trParams({'label': step.label}),
        message: 'orders.guided_filter.no_options_message'.tr,
      );
    } else if (step.role == FilterStepRole.family) {
      selector = ProductFamilySelector(
        options: state.activeOptions,
        selectedValue: state.selection.valueFor(step.key),
        countLabelBuilder: (count) =>
            'orders.guided_filter.items_count'.trParams({'count': count}),
        onSelect: select,
      );
    } else {
      selector = DynamicFilterSection(
        step: step,
        options: state.activeOptions,
        selectedValue: state.selection.valueFor(step.key),
        onSelect: select,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterStageHeader(
          title: 'orders.guided_filter.select_label'
              .trParams({'label': step.label}),
          subtitle: 'orders.guided_filter.step_progress'.trParams({
            'current': state.activeStepNumber,
            'total': state.totalSteps,
          }),
        ),
        SizedBox(height: context.rh(12)),
        selector,
      ],
    );
  }
}
