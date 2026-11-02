import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_by_id.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_state.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';
import 'package:steelforce/features/order/presentation/screens/sales_order/sales_order_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/order_skeletons.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';
import 'package:steelforce/shared/widgets/back_to_home.dart';

class QuotationDetailScreen extends StatefulWidget {
  const QuotationDetailScreen({
    super.key,
    this.quotation,
    this.quotationId,
  }) : assert(quotation != null || quotationId != null,
            'Either quotation or quotationId must be provided.');

  static const routeName = 'order-quotation-detail';

  final Quotation? quotation;
  final String? quotationId;

  /// The id the API knows this quotation by.
  ///
  /// A quotation handed over from the local list carries its *device* id in
  /// [Quotation.id]; the server's id, once it has one, is
  /// [Quotation.remoteId]. Asking the API for the device id failed every time,
  /// so the screen fell back to the stale local copy even while online. A
  /// quotation with no remote id has never reached the server, and the local
  /// fallback below is the right answer for it.
  String get effectiveId => quotationId ?? quotation!.remoteId ?? quotation!.id;

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  @override
  void initState() {
    super.initState();
    AppCoach.notify(CoachAction.openQuotationDetails);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveId = widget.effectiveId;
    return BlocProvider<QuotationDetailCubit>(
      create: (_) => sl<QuotationDetailCubit>()..load(effectiveId),
      child: LocalizedBuilder(
        builder: (ctx) => _QuotationDetailView(
          quotationId: effectiveId,
          fallbackQuotation: widget.quotation,
        ),
      ),
    );
  }
}

class _QuotationDetailView extends StatelessWidget {
  const _QuotationDetailView({
    required this.quotationId,
    this.fallbackQuotation,
  });

  final String quotationId;
  final Quotation? fallbackQuotation;

  Future<void> _editQuotation(
      BuildContext context, QuotationDetail detail) async {
    Depot? depot;
    if (detail.depotId.isNotEmpty) {
      final result = await sl<GetDepotById>()(DepotIdParams(detail.depotId));
      depot = result.when(success: (c) => c, failure: (_) => null);
    }
    if (!context.mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: QuotationBuilderScreen.routeName),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => sl<CartCubit>()),
          BlocProvider(create: (_) => sl<SyncCubit>()),
        ],
        child: LocalizedBuilder(
          builder: (_) => QuotationBuilderScreen(
            depot: depot,
            depotId: detail.depotId,
            editingQuotationId: detail.id,
          ),
        ),
      ),
    ));
  }

  void _convertToSalesOrder(BuildContext context, QuotationDetail detail) {
    if (fallbackQuotation != null) {
      Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: SalesOrderScreen.routeName),
        builder: (_) => BlocProvider(
          create: (_) => sl<CartCubit>()..loadFromQuotation(fallbackQuotation!),
          child: SalesOrderScreen(quotation: fallbackQuotation!),
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('orders.quotation_detail.conversion_next_phase'.tr)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return BlocConsumer<QuotationDetailCubit, QuotationDetailState>(
      listener: (context, state) {
        if (state is QuotationDetailLoaded && state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }

        // Handle 409 Quotation.PriceChanged loop
        if (state is QuotationDetailPriceChanged) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Text('orders.quotation_detail.price_changed_title'.tr),
                ],
              ),
              content: Text(
                'orders.quotation_detail.price_changed_body'
                    .trParams({'message': state.message}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('common.cancel'.tr),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    context.read<QuotationDetailCubit>().reprice();
                  },
                  child: Text('orders.quotation_detail.reprice_and_review'.tr),
                ),
              ],
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: colors.textPrimary,
                    size: context.rsp(28),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    'orders.quotation.details_title'.tr,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: context.rw(16)),
                child: const BackToHomeButton(),
              ),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, QuotationDetailState state) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    if (state is QuotationDetailLoading || state is QuotationDetailInitial) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: PendingOrdersSkeleton(),
      );
    }

    if (state is QuotationDetailError) {
      if (fallbackQuotation != null) {
        final detail = _fromLocalQuotation(fallbackQuotation!);
        return _buildDetailContent(
          context,
          detail: detail,
          history: const <QuotationApprovalHistory>[],
          isSubmitting: false,
          isCancelling: false,
          theme: theme,
          colors: colors,
          isOfflineDraft: true,
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: colors.warning),
              const SizedBox(height: 12),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    context.read<QuotationDetailCubit>().load(quotationId),
                child: Text('common.retry'.tr),
              ),
            ],
          ),
        ),
      );
    }

    final detail = state is QuotationDetailLoaded
        ? state.quotation
        : (state as QuotationDetailPriceChanged).quotation;
    final history = state is QuotationDetailLoaded
        ? state.history
        : const <QuotationApprovalHistory>[];
    final isSubmitting = state is QuotationDetailLoaded && state.isSubmitting;
    final isCancelling = state is QuotationDetailLoaded && state.isCancelling;

    return _buildDetailContent(
      context,
      detail: detail,
      history: history,
      isSubmitting: isSubmitting,
      isCancelling: isCancelling,
      theme: theme,
      colors: colors,
      isOfflineDraft: false,
    );
  }

  static QuotationDetail _fromLocalQuotation(Quotation q) {
    return QuotationDetail(
      id: q.id,
      number: q.id,
      depotId: q.depotId ?? '',
      depotName: q.shopName,
      status: q.status.name,
      statusGroup: QuotationStatusGroup.drafts,
      shipmentType: 'Pickup',
      currency: 'USD',
      lines: q.lines.asMap().entries.map((e) {
        final item = e.value;
        return QuotationLineItem(
          id: '${q.id}-${e.key}',
          lineNumber: e.key + 1,
          materialNumber: item.product.code,
          materialDescription: item.product.name,
          quantity: item.quantity.toDouble(),
          unit: item.product.unit,
          priceAmount: item.unitPrice,
          priceCurrency: 'USD',
          pricePricingUnit: 1,
          priceConditionUnit: item.product.unit,
          discounts: const [],
          gross: item.lineSubtotal,
          discountTotal: item.lineDiscount,
          net: item.lineTotal,
        );
      }).toList(),
      totals: QuotationTotals(
        currency: 'USD',
        gross: q.subtotal,
        discountTotal: q.discount,
        net: q.total,
        tax: q.tax,
        isEstimate: true,
      ),
      revision: 1,
      requiredApprovalLevel: 1,
      validTo: q.validUntil,
      createdAt: q.createdAt,
      updatedAt: q.updatedAt,
    );
  }

  Widget _buildDetailContent(
    BuildContext context, {
    required QuotationDetail detail,
    required List<QuotationApprovalHistory> history,
    required bool isSubmitting,
    required bool isCancelling,
    required ThemeData theme,
    required AppThemeColors colors,
    bool isOfflineDraft = false,
  }) {
    final statusStyle = _resolveStatusStyle(detail.status, theme, colors);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        if (isOfflineDraft) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded,
                    color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'orders.quotation_detail.offline_draft'.tr,
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.rh(12)),
        ],
        // Top row: Document Number + Status Chip + Revision
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.number.isNotEmpty ? detail.number : detail.id,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(19),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (detail.revision > 1)
                    Text(
                      'orders.quotation_detail.revision'
                          .trParams({'number': '${detail.revision}'}),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusStyle.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                detail.status,
                style: TextStyle(
                  color: statusStyle.textColor,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(6)),
        // Depot Name
        Text(
          detail.depotName ??
              'orders.quotation_detail.depot_fallback'
                  .trParams({'id': detail.depotId}),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(14),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (detail.validTo != null) ...[
          SizedBox(height: context.rh(4)),
          Text(
            '${'orders.quotation.valid_until'.tr}: ${_formatDate(detail.validTo!)}',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12),
            ),
          ),
        ],

        // Decision Reason banner if returned or rejected
        if (detail.decisionReason != null &&
            detail.decisionReason!.isNotEmpty) ...[
          SizedBox(height: context.rh(12)),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'orders.quotation_detail.decision_reason'.tr,
                        style: TextStyle(
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.decisionReason!,
                        style: TextStyle(
                          fontSize: context.rsp(13),
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: context.rh(16)),

        // Items Table
        _QuotationLinesTable(lines: detail.lines),

        SizedBox(height: context.rh(16)),

        // Totals Card
        _DetailTotalsCard(totals: detail.totals),

        // Approval History Timeline (if present)
        if (history.isNotEmpty) ...[
          SizedBox(height: context.rh(20)),
          Text(
            'orders.quotation_detail.approval_trail'.tr,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(15),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rh(8)),
          _ApprovalHistoryView(history: history),
        ],

        SizedBox(height: context.rh(24)),

        // Actions based on state
        if (detail.isEditable) ...[
          // Submit for Approval button
          SizedBox(
            width: double.infinity,
            child: CoachKeys.wrap(
              CoachKeys.quotationSubmit,
              child: ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () => _submit(context.read<QuotationDetailCubit>()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'orders.quotation_detail.submit_for_approval'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
          SizedBox(height: context.rh(10)),
          // Edit Quotation button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _editQuotation(context, detail),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('orders.quotation.edit_quotation'.tr),
            ),
          ),
          SizedBox(height: context.rh(10)),
          // Cancel Quotation button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: isCancelling
                  ? null
                  : () async {
                      final confirmed = await _confirmCancelDialog(context);
                      if (confirmed == true && context.mounted) {
                        context.read<QuotationDetailCubit>().cancel();
                      }
                    },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              child: isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('orders.quotation_detail.withdraw'.tr),
            ),
          ),
        ] else if (detail.isPendingApproval) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isCancelling
                  ? null
                  : () async {
                      final confirmed = await _confirmCancelDialog(context);
                      if (confirmed == true && context.mounted) {
                        context.read<QuotationDetailCubit>().cancel();
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text('orders.quotation_detail.withdraw_from_approval'.tr),
            ),
          ),
        ] else if (detail.status.toLowerCase() == 'quoted' ||
            detail.status.toLowerCase() == 'accepted') ...[
          SizedBox(
            width: double.infinity,
            child: CoachKeys.wrap(
              CoachKeys.quotationConvert,
              child: ElevatedButton(
                onPressed: () => _convertToSalesOrder(context, detail),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('orders.quotation.convert_to_sales_order'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Submits, then tells the App Coach how it went — success only once the
  /// backend accepted it, failure on any refusal (price changed included).
  Future<void> _submit(QuotationDetailCubit cubit) async {
    final submitted = await cubit.submit();
    if (submitted == null) return;
    AppCoach.notify(submitted
        ? CoachAction.submitQuotationSucceeded
        : CoachAction.submitQuotationFailed);
  }

  Future<bool?> _confirmCancelDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('orders.quotation_detail.cancel_title'.tr),
        content: Text('orders.quotation_detail.cancel_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('orders.quotation_detail.cancel_no'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text('orders.quotation_detail.cancel_yes'.tr),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static ({Color backgroundColor, Color textColor}) _resolveStatusStyle(
      String status, ThemeData theme, AppThemeColors colors) {
    final s = status.toLowerCase();
    if (s.contains('draft')) {
      return (
        backgroundColor: colors.surfaceSoft,
        textColor: colors.textSecondary,
      );
    }
    if (s.contains('returned') ||
        s.contains('waiting') ||
        s.contains('pending')) {
      return (
        backgroundColor: Colors.amber.withValues(alpha: 0.15),
        textColor: Colors.amber.shade900,
      );
    }
    if (s.contains('approved') ||
        s.contains('won') ||
        s.contains('accepted') ||
        s.contains('ordered')) {
      return (
        backgroundColor: Colors.green.withValues(alpha: 0.15),
        textColor: Colors.green.shade800,
      );
    }
    if (s.contains('rejected') ||
        s.contains('cancelled') ||
        s.contains('failed') ||
        s.contains('lost') ||
        s.contains('expired')) {
      return (
        backgroundColor: Colors.red.withValues(alpha: 0.15),
        textColor: Colors.red.shade800,
      );
    }
    if (s.contains('quoted')) {
      return (
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        textColor: theme.colorScheme.primary,
      );
    }
    return (
      backgroundColor: colors.surfaceSoft,
      textColor: colors.textPrimary,
    );
  }
}

class _QuotationLinesTable extends StatelessWidget {
  const _QuotationLinesTable({required this.lines});

  final List<QuotationLineItem> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'orders.quotation_detail.col_material'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'orders.quotation_detail.col_qty_price'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'orders.quotation_detail.col_net'.tr,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            separatorBuilder: (_, __) =>
                Divider(color: colors.divider, height: 1),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.materialDescription.isNotEmpty
                                ? line.materialDescription
                                : line.materialNumber,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            line.materialNumber,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                            ),
                          ),
                          // Discounts badges
                          if (line.discounts.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: line.discounts.map((d) {
                                final isAg =
                                    d.kind == QuotationDiscountKind.agreement;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAg
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    (isAg
                                            ? 'orders.quotation_detail.discount_agreement'
                                            : 'orders.quotation_detail.discount_rep')
                                        .trParams({
                                      'percent': d.percent.toStringAsFixed(1),
                                    }),
                                    style: TextStyle(
                                      fontSize: context.rsp(10),
                                      fontWeight: FontWeight.w700,
                                      color: isAg
                                          ? Colors.blue.shade800
                                          : Colors.orange.shade900,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${line.quantity.toStringAsFixed(0)} ${line.unit}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(12.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            line.formattedPrice,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        PricingText.amount(
                          line.net,
                          currency: line.priceCurrency,
                        ),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(13.5),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailTotalsCard extends StatelessWidget {
  const _DetailTotalsCard({required this.totals});

  final QuotationTotals totals;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(context.rr(14)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          _TotalsRow(
            label: 'orders.quotation_detail.subtotal_gross'.tr,
            amount: totals.gross,
            currency: totals.currency,
          ),
          if (totals.discountTotal > 0) ...[
            const SizedBox(height: 8),
            _TotalsRow(
              label: 'orders.quotation_detail.discounts_total'.tr,
              amount: -totals.discountTotal,
              currency: totals.currency,
              textColor: Colors.green.shade700,
            ),
          ],
          const SizedBox(height: 8),
          _TotalsRow(
            label: totals.tax == null || totals.tax! <= 0
                ? 'orders.quotation_detail.tax_exempt'.tr
                : 'orders.sales_order.tax'.tr,
            amount: totals.tax ?? 0.0,
            currency: totals.currency,
          ),
          Divider(color: colors.divider, height: 20),
          _TotalsRow(
            label: 'orders.quotation_detail.total_net'.tr,
            amount: totals.net,
            currency: totals.currency,
            isEmphasized: true,
            textColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.textColor,
    this.isEmphasized = false,
  });

  final String label;
  final double amount;
  final String currency;
  final Color? textColor;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isEmphasized ? colors.textPrimary : colors.textSecondary,
            fontSize: context.rsp(isEmphasized ? 15 : 13),
            fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          PricingText.amount(amount, currency: currency),
          style: TextStyle(
            color: textColor ?? colors.textPrimary,
            fontSize: context.rsp(isEmphasized ? 16 : 13),
            fontWeight: isEmphasized ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ApprovalHistoryView extends StatelessWidget {
  const _ApprovalHistoryView({required this.history});

  final List<QuotationApprovalHistory> history;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length,
        separatorBuilder: (_, __) => Divider(color: colors.divider, height: 1),
        itemBuilder: (context, index) {
          final record = history[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            record.action,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _formatDateTime(record.createdAt),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: context.rsp(11),
                            ),
                          ),
                        ],
                      ),
                      if (record.actorName != null &&
                          record.actorName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'orders.quotation_detail.by_actor'
                              .trParams({'name': record.actorName!}),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11.5),
                          ),
                        ),
                      ],
                      if (record.comment != null &&
                          record.comment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          record.comment!,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: context.rsp(12),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
