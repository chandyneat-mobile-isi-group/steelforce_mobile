import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/empty_products.dart';

class FilterFailureState extends StatelessWidget {
  const FilterFailureState({super.key, required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => EmptyProducts(
        icon: Icons.error_outline_rounded,
        title: 'orders.guided_filter.error_title'.tr,
        message: message,
        action: TextButton(
          onPressed: () => context
              .read<ProductFilterFlowBloc>()
              .add(const FilterFlowStarted()),
          child: Text('common.retry'.tr),
        ),
      );
}
