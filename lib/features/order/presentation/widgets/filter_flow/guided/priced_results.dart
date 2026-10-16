import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';

/// Keeps [PricingCubit] asking about exactly the materials on screen, and
/// hands the resulting prices to [builder].
///
/// ## Why this is stateful
///
/// [PricingCubit.track] emits its loading state *synchronously*. Calling it
/// from inside a `build` — which is where the promotion equivalent is called,
/// because that one is timer-debounced — would mutate a cubit during the build
/// that is reading it, which Flutter rejects outright. So the request is
/// scheduled after the frame instead.
///
/// ## Why it asks for everything on screen at once
///
/// The endpoint takes a repeatable `materials` parameter, so a page of results
/// costs one round trip rather than one per card. The list is built lazily as
/// the rep scrolls, which keeps that batch to what is actually being looked at
/// — the endpoint's own guidance is that naming a few materials is much faster
/// than naming forty.
class PricedResults extends StatefulWidget {
  const PricedResults(
      {super.key, required this.products, required this.builder});

  final List<Product> products;
  final Widget Function(BuildContext context, Map<String, MobilePrice> prices)
      builder;

  @override
  State<PricedResults> createState() => _PricedResultsState();
}

class _PricedResultsState extends State<PricedResults> {
  /// What has already been handed to the cubit, so a rebuild does not schedule
  /// a callback per frame on a list the rep is scrolling.
  final Set<String> _requested = {};

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(covariant PricedResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    _track();
  }

  void _track() {
    final fresh = <String>{
      for (final product in widget.products)
        if (product.materialNumber.trim().isNotEmpty) product.materialNumber,
    }..removeAll(_requested);
    if (fresh.isEmpty) return;

    _requested.addAll(fresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The cubit is idempotent and skips anything already priced, so a
      // duplicate here costs nothing.
      unawaited(context.read<PricingCubit>().track(fresh));
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PricingCubit, Map<String, MobilePrice>>(
        builder: widget.builder,
      );
}
