import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/favorite_products_mixin.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/my_visits/presentation/navigation/end_visit.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/services/image_search_service.dart';
import 'package:steelforce/features/order/domain/services/voice_search_service.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/stock_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_state.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/pricing/pricing_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/promotion/promotion_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/customized_product_form_screen.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotion_section.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/catalog/sync_status_banner.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/cart_line_binding.dart';
import 'package:steelforce/features/order/presentation/widgets/filter_flow/guided_product_filter_view.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/cart_preview_section.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/manual_price_input_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/quotation_bottom_bar.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/shipment_widget_section.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_state.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_totals.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/manual_price_book.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/builder/quotation_builder_preview.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/builder/depot_credit_summary.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/builder/quotation_builder_app_bar.dart';

/// Quotation builder — a guided product finder rather than a catalog dump.
class QuotationBuilderScreen extends StatefulWidget {
  const QuotationBuilderScreen({
    super.key,
    this.depot,
    this.depotId,
    this.leadId,
    this.leadDisplayName,
    this.offVisitReason,
    this.gpsLat,
    this.gpsLng,
    this.editingQuotation,
    this.editingQuotationId,
  });

  static const routeName = 'order-quotation-builder';

  final Depot? depot;

  /// The depot this quotation is for, when only their id is known.
  ///
  /// Several entry points open the builder for a shop the rep has already
  /// chosen — the depot card's "create quotation", the checked-in visit
  /// flow, the Continue-Working resume — and have the id without having loaded
  /// the whole [Depot]. They used to pass it as [leadId], which is the only
  /// slot that existed, so everything scoped to the depot read null and
  /// behaved as though the rep were serving a walk-in.
  ///
  /// **Read it through [depotContextId], never on its own.** It is
  /// deliberately not wired into the cart or the saved quotation: those still
  /// key off [leadId] exactly as before, and changing that would rewrite how
  /// existing lines merge and how a quotation is filed.
  final String? depotId;

  final String? leadId;
  final String? leadDisplayName;
  final OffVisitReason? offVisitReason;
  final double? gpsLat;
  final double? gpsLng;
  final Quotation? editingQuotation;
  final String? editingQuotationId;

  /// The backend document to reopen. A local quotation's own [Quotation.id]
  /// is a device id the backend has never heard of — sending it answered
  /// `404` and put the builder in its error state — so only its [Quotation.
  /// remoteId] qualifies. A quotation created offline has none, and the
  /// builder opens a fresh server draft for it instead.
  String? get effectiveQuotationId =>
      editingQuotationId ?? editingQuotation?.remoteId;

  /// Whose account this quotation is being built against, however the caller
  /// happened to supply it.
  ///
  /// The one place anything depot-scoped — pricing, promotions — should ask.
  /// Null means a genuine walk-in with no account, which is a real state and
  /// renders as such; it must not be conflated with "the caller only had the
  /// id", which is what reading `depot?.id` alone did.
  ///
  /// [leadId] is **not** a fallback here. A lead is an unregistered shop with
  /// no SAP account, so sending its id to `/pricing/depots/{id}` would 404
  /// and surface as "depot not found" — an error, where the honest answer is
  /// that there is nobody to price for yet.
  String? get depotContextId => depot?.id ?? depotId;

  @override
  State<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends State<QuotationBuilderScreen>
    with FavoriteProductsMixin {
  final ManualPriceBook _manualPrices = ManualPriceBook();

  // Shipment & Payment selection states
  ShipmentMethod _shipmentMethod = ShipmentMethod.pickup;
  PickupLocation? _pickupLocation = PickupLocation.factory;
  DeliveryAddressOption? _deliveryOption;
  bool _isCod = false;

  /// Tax Invoice (10%) when true, Commercial Invoice (0%) when false.
  bool _isTaxApplicable = true;

  final TextEditingController _newAddressController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();

  /// Owned here rather than looked up from `context`.
  late final StockCubit _stock = sl<StockCubit>();
  late final PricingCubit _pricing = sl<PricingCubit>()
    ..setDepot(widget.depotContextId);
  late final QuotationBuilderCubit _builderCubit = sl<QuotationBuilderCubit>();

  @override
  void initState() {
    super.initState();

    context.read<SyncCubit>().syncIfNeeded();
    loadFavorites();

    if (widget.depotContextId != null) {
      _builderCubit.initialize(
        depotId: widget.depotContextId!,
        existingQuotationId: widget.effectiveQuotationId,
        shipmentType: _shipmentType,
        shipTo: _shipTo(_deliveryOption),
      );
    }
  }

  @override
  void dispose() {
    _newAddressController.dispose();
    _newPhoneController.dispose();
    _stock.close();
    _pricing.close();
    _builderCubit.close();
    super.dispose();
  }

  String get _shipmentType =>
      _shipmentMethod == ShipmentMethod.pickup ? 'Pickup' : 'Delivery';

  String? _shipTo(DeliveryAddressOption? option) =>
      option == DeliveryAddressOption.newAddress
          ? _newAddressController.text
          : widget.depot?.address;

  CartLineBinding get _cartLines => CartLineBinding(
        cart: context.read<CartCubit>(),
        leadId: widget.leadId,
        depotId: widget.depot?.id,
        priceResolver: (product) => _manualPrices.priceFor(
            product, _pricing.state[product.materialNumber]),
        isManualPriceResolver: (product) => _manualPrices.isManual(
            product, _pricing.state[product.materialNumber]),
      );

  Future<void> _handleInputPrice(Product product) async {
    final p = _pricing.state[product.materialNumber];
    if (p != null && p.hasAmount) return;

    final existing = _cartLines.lineFor(product);
    final currentPrice = existing?.isManualPrice == true
        ? existing?.unitPriceOverride
        : _manualPrices.of(product);

    final entered = await showManualPriceInputSheet(
      context: context,
      product: product,
      unit: product.unit,
      currentPrice: currentPrice,
    );

    if (entered == null || !mounted) return;

    setState(() => _manualPrices.remember(product, entered));

    await _cartLines.setManualPrice(
      product,
      entered > 0 ? entered : null,
    );
  }

  /// The preview's price editor for a line already in the cart.
  Future<void> _editLinePrice(CartItem item) async {
    final p = _pricing.state[item.product.materialNumber];
    if (p != null && p.hasAmount) return;

    final cartCubit = context.read<CartCubit>();
    final price = await showManualPriceInputSheet(
      context: context,
      item: item,
      currentPrice: item.isManualPrice ? item.unitPriceOverride : null,
    );
    if (price != null && mounted) {
      setState(() => _manualPrices.remember(item.product, price));
      await cartCubit.updateUnitPrice(
        item.id,
        price > 0 ? price : null,
        isManualPrice: true,
      );
    }
  }

  void _openCustomize(Product product) {
    final cartCubit = context.read<CartCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cartCubit,
          child: CustomizedProductFormScreen(
            baseProduct: product,
            leadId: widget.leadId,
            depotId: widget.depot?.id,
          ),
        ),
      ),
    );
  }

  /// Sets a cart line's quantity.
  ///
  /// **No stock gate.** A rep may quote any catalogue material; SAP's stock
  /// verdict is settled later in the workflow. A live check here refused
  /// orderable lines, because the handset often lacked the sales area it
  /// answers for — and "none at this plant today" is no reason not to quote.
  /// The binding's own validation (credit limit, missing depot) still runs.
  Future<void> _setLineQuantity(Product product, int quantity) async {
    // Still asked, still shown further down the flow — just not a gate. Held
    // for five minutes and deduplicated, so this costs nothing per tap.
    unawaited(_stock.ensure(product.materialNumber));
    await _writeLine(product, quantity);

    unawaited(_builderCubit.syncLineQuantity(
      materialNumber: product.materialNumber,
      quantity: quantity,
      unit: product.unit,
    ));
  }

  void _onShipmentMethodChanged(ShipmentMethod method) {
    setState(() {
      _shipmentMethod = method;
      if (method == ShipmentMethod.pickup) {
        _pickupLocation ??= PickupLocation.factory;
        _deliveryOption = null;
      } else {
        _deliveryOption ??= DeliveryAddressOption.defaultAddress;
        _pickupLocation = null;
      }
    });
    unawaited(_builderCubit.updateHeader(
      shipmentType: _shipmentType,
      shipTo: _shipTo(_deliveryOption),
    ));
  }

  void _onDeliveryOptionChanged(DeliveryAddressOption option) {
    setState(() => _deliveryOption = option);
    if (_shipmentMethod == ShipmentMethod.delivery) {
      unawaited(_builderCubit.updateHeader(
        shipmentType: 'Delivery',
        shipTo: _shipTo(option),
      ));
    }
  }

  /// The single write into the quotation, and the only place its rejections
  /// are reported.
  Future<void> _writeLine(Product product, int quantity) async {
    final verdict = await _cartLines.setQuantity(product, quantity);
    if (verdict.isValid || !mounted) return;

    // Whatever else the binding rejects — a credit limit, a missing depot —
    // still gets said. What it no longer does is interpolate a stock figure
    // and a warehouse that were always going to come out blank.
    final key = verdict.messageKey;
    if (key == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr)));
  }

  /// The "Complete Visit" action beside Save. Ends the visit and drains the
  /// outbound queue — see [endVisitAndSync] for why the check-out is committed
  /// before the push rather than alongside it.
  void _completeVisit() {
    unawaited(endVisitAndSync(context));
  }

  Future<void> _saveQuotation() async {
    final bState = _builderCubit.state;
    final totals = QuotationBuilderTotals.resolve(
      bState,
      context.read<CartCubit>().state,
      isTaxApplicable: _isTaxApplicable,
    );

    final quotation = await context.read<CartCubit>().saveQuotation(
          depotId: widget.depot?.id,
          shopName: widget.depot?.shopName,
          leadId: widget.leadId,
          leadDisplayName: widget.leadDisplayName,
          offVisitReason: widget.offVisitReason,
          gpsLat: widget.gpsLat,
          gpsLng: widget.gpsLng,
          editing: widget.editingQuotation,
          subtotal: totals.subtotal,
          discount: totals.discount,
          tax: totals.tax,
          total: totals.total,
          // Links the local copy to the server draft the builder was pricing
          // against, so the sync queue submits that document rather than
          // creating a second one.
          remoteId:
              bState is QuotationBuilderReady ? bState.quotation.id : null,
        );

    if (!mounted) return;
    final effectiveId =
        (bState is QuotationBuilderReady ? bState.quotation.id : null) ??
            quotation?.id;
    if (effectiveId == null && quotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.quotation_extra.save_failed'.tr)));
      return;
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      settings: const RouteSettings(name: QuotationDetailScreen.routeName),
      builder: (_) => QuotationDetailScreen(
        quotationId: effectiveId,
        quotation: quotation,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProductFilterFlowBloc>(
          create: (_) =>
              sl<ProductFilterFlowBloc>()..add(const FilterFlowStarted()),
        ),
        // Sits above the product list so every card and stepper below reads the
        // same per-material verdicts. `.value`, not `create` — the instance
        // belongs to the State so that `_setLineQuantity` can use it without a
        // context lookup that would search above this provider.
        BlocProvider<StockCubit>.value(value: _stock),
        // Scoped to this quotation's depot. Entitlements are per account:
        // a negotiated deal for one shop must never surface against another,
        // and a walk-in sees only unscoped promotions.
        BlocProvider<PromotionCubit>(
          create: (_) => sl<PromotionCubit>()..setDepot(widget.depotContextId),
        ),
        // Same scoping, and for a stronger reason: SAP prices a material *for
        // a depot*, so there is no such thing as this quotation's price
        // without knowing whose it is. A walk-in has no depot id, and the
        // cards say "select a depot" rather than showing a figure quoted
        // for somebody else.
        BlocProvider<PricingCubit>.value(
          value: _pricing,
        ),
        BlocProvider<QuotationBuilderCubit>.value(
          value: _builderCubit,
        ),
      ],
      child: BlocListener<SyncCubit, SyncState>(
        listenWhen: (a, b) => b is SyncSucceeded && b.changedAnything,
        listener: (context, _) {
          context.read<ProductFilterFlowBloc>().add(const FilterFlowStarted());
          // A resync can change what is sellable and from where, so the held
          // verdicts are now describing a catalog that has moved underneath
          // them. Dropping them costs a round trip on next use and avoids
          // showing a band that predates the sync.
          _stock.invalidate();
        },
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: QuotationBuilderAppBar(
            title: widget.depot?.shopName ??
                widget.leadDisplayName ??
                'orders.quotation.builder_title'.tr,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    const SyncStatusBanner(),
                    if (widget.depot != null)
                      DepotCreditSummary(depot: widget.depot!),
                    GuidedProductFilterView(
                      sticky: false,
                      depotId: widget.depot?.id,
                      leadId: widget.leadId,
                      favoriteIds: favoriteIds,
                      onToggleFavorite: toggleFavorite,
                      quantityFor: (product) => _cartLines.quantityFor(product),
                      onQuantityChanged: _setLineQuantity,
                      lineTotalFor: (product, quantity) =>
                          _cartLines.lineTotalLabel(product, quantity),
                      onCustomize: _openCustomize,
                      onVoiceSearch: () => sl<VoiceSearchService>().listen(),
                      onImageSearch: () => sl<ImageSearchService>()
                          .matchQuery(ImageSearchSource.gallery),
                      onInputPrice: _handleInputPrice,
                      hostManualPriceFor: _manualPrices.of,
                    ),
                    SizedBox(height: context.rh(16)),

                    ShipmentSelectionWidget(
                      method: _shipmentMethod,
                      pickupLocation: _pickupLocation,
                      deliveryOption: _deliveryOption,
                      isCod: _isCod,
                      isTaxApplicable: _isTaxApplicable,
                      defaultAddress: widget.depot?.address,
                      newAddressController: _newAddressController,
                      newPhoneController: _newPhoneController,
                      onMethodChanged: _onShipmentMethodChanged,
                      onPickupLocationChanged: (location) =>
                          setState(() => _pickupLocation = location),
                      onDeliveryOptionChanged: _onDeliveryOptionChanged,
                      onCodChanged: (isCod) => setState(() => _isCod = isCod),
                      onTaxApplicableChanged: (isTaxApplicable) =>
                          setState(() => _isTaxApplicable = isTaxApplicable),
                    ),
                    SizedBox(height: context.rh(16)),
                    // Fed from the shipment state above, so the block
                    // re-evaluates on every change: the COD / Pickup discount
                    // is earned by collecting from the depot, and switching to
                    // Delivery must take it off the table rather than leave a
                    // rate on screen that the invoice will not honour.
                    PromotionSectionWidget(
                      depotId: widget.depotContextId,
                      terms: OrderTerms(
                        isPickup: _shipmentMethod == ShipmentMethod.pickup,
                      ),
                    ),
                    SizedBox(height: context.rh(16)),
                    const CartPreviewSection(),
                    QuotationBuilderPreview(
                      depot: widget.depot,
                      leadDisplayName: widget.leadDisplayName,
                      effectiveQuotationId: widget.effectiveQuotationId,
                      isTaxApplicable: _isTaxApplicable,
                      onEditPrice: _editLinePrice,
                    ),
                    SizedBox(height: context.rh(16)),
                  ],
                ),
              ),
              QuotationBottomBar(
                onSave: _saveQuotation,
                backLabelKey: 'my_visits.inventory.completion.complete_visit',
                onBack: _completeVisit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
