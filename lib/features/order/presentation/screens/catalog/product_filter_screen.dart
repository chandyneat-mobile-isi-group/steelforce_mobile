import 'package:flutter/material.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/favorite_products_mixin.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/promotion/promotion_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_state.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_line_binding.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided_product_filter_view.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Standalone guided product configurator.
///
/// Replaces the old "everything on one page" filter screen: no product query
/// runs until the rep has walked the category's filter hierarchy to the end.
/// The screen itself is thin — [GuidedProductFilterView] renders the flow and
/// [ProductFilterFlowBloc] owns every piece of its state.
class ProductFilterScreen extends StatefulWidget {
  const ProductFilterScreen({super.key, this.leadId, this.depotId});

  static const routeName = 'order-product-filter';

  final String? leadId;
  final String? depotId;

  static Widget provider({String? leadId, String? depotId}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) =>
                sl<ProductFilterFlowBloc>()..add(const FilterFlowStarted())),
        BlocProvider(create: (_) => sl<CartCubit>()..load()),
        // The finder pulls the catalog itself rather than assuming whichever
        // screen the rep arrived from already did. Entering here on a device
        // with nothing synced used to leave an empty category picker with no
        // way out.
        BlocProvider(create: (_) => sl<SyncCubit>()..syncIfNeeded()),
        // Both are read by the shared product stage, so this screen has to
        // supply them or the result list throws a ProviderNotFound the moment
        // it renders a card. Scoped to the depot for the same reason in
        // both cases: promotions are entitlements per account, and SAP prices
        // a material *for a depot* — neither means anything unscoped.
        BlocProvider(
          create: (_) => sl<PromotionCubit>()..setDepot(depotId),
        ),
        BlocProvider(
          create: (_) => sl<PricingCubit>()..setDepot(depotId),
        ),
      ],
      child: ProductFilterScreen(leadId: leadId, depotId: depotId),
    );
  }

  @override
  State<ProductFilterScreen> createState() => _ProductFilterScreenState();
}

class _ProductFilterScreenState extends State<ProductFilterScreen>
    with FavoriteProductsMixin {
  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  /// The quantity stepper on each card is the only write path into the cart —
  /// zero removes the line, so there is no separate add or delete action.
  CartLineBinding get _cartLines => CartLineBinding(
        cart: context.read<CartCubit>(),
        leadId: widget.leadId,
        depotId: widget.depotId,
        priceResolver: (product) {
          try {
            final p =
                context.read<PricingCubit>().state[product.materialNumber];
            if (p != null && p.hasAmount) return p.price;
          } catch (_) {}
          return null;
        },
      );

  /// System back retraces the flow one step at a time before leaving the
  /// screen — the rep's selections are never thrown away by a stray back tap.
  /// Returns true once there is nothing left to retrace.
  bool _stepBack() {
    final bloc = context.read<ProductFilterFlowBloc>();
    if (!bloc.state.canGoBack) return true;
    bloc.add(const FilterFlowBackRequested());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_stepBack()) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.canvas,
          elevation: 0,
          iconTheme: IconThemeData(color: colors.textPrimary),
          title: BlocBuilder<ProductFilterFlowBloc, ProductFilterFlowState>(
            buildWhen: (a, b) => a.category != b.category,
            builder: (context, state) => Text(
              context.localizedOrNull(state.category?.name) ??
                  'orders.filter.title'.tr,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          actions: [
            BlocBuilder<ProductFilterFlowBloc, ProductFilterFlowState>(
              buildWhen: (a, b) => a.canGoBack != b.canGoBack,
              builder: (context, state) => state.canGoBack
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: () => context
                            .read<ProductFilterFlowBloc>()
                            .add(const FilterFlowReset()),
                        child: Text('common.clear_all'.tr,
                            style: TextStyle(color: colors.warning)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        // A sync that lands after the flow has already read an empty catalog
        // has to be picked up, otherwise the rep sits on "no categories" while
        // the data they need is on the device.
        body: BlocListener<SyncCubit, SyncState>(
          listenWhen: (a, b) => b is SyncSucceeded && b.changedAnything,
          listener: (context, _) => context
              .read<ProductFilterFlowBloc>()
              .add(const FilterFlowStarted()),
          child: GuidedProductFilterView(
            depotId: widget.depotId,
            leadId: widget.leadId,
            favoriteIds: favoriteIds,
            onToggleFavorite: toggleFavorite,
            quantityFor: (product) => _cartLines.quantityFor(product),
            onQuantityChanged: (product, quantity) =>
                _cartLines.setQuantity(product, quantity),
            lineTotalFor: (product, quantity) =>
                _cartLines.lineTotalLabel(product, quantity),
          ),
        ),
      ),
    );
  }
}
