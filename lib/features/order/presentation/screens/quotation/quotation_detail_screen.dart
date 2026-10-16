import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_by_id.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_offline_detail.dart';
import 'package:steelforce/features/order/presentation/bloc/cart/cart_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_state.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';
import 'package:steelforce/features/order/presentation/screens/sales_order/sales_order_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/order_skeletons.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_detail_content.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/detail/quotation_price_changed_dialog.dart';
import 'package:steelforce/shared/widgets/back_to_home.dart';

class QuotationDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider<QuotationDetailCubit>(
      create: (_) => sl<QuotationDetailCubit>()..load(effectiveId),
      child: LocalizedBuilder(
        builder: (ctx) => _QuotationDetailView(
          quotationId: effectiveId,
          fallbackQuotation: quotation,
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
        const SnackBar(
            content: Text('Order conversion will be available in next phase.')),
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
        if (state is QuotationDetailPriceChanged) {
          showQuotationPriceChangedDialog(
            context,
            message: state.message,
            onReprice: () => context.read<QuotationDetailCubit>().reprice(),
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
    if (state is QuotationDetailLoading || state is QuotationDetailInitial) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: PendingOrdersSkeleton(),
      );
    }

    if (state is QuotationDetailError) {
      if (fallbackQuotation != null) {
        return _content(
          context,
          detail: fallbackQuotation!.toOfflineDetail(),
          history: const <QuotationApprovalHistory>[],
          isSubmitting: false,
          isCancelling: false,
          isOfflineDraft: true,
        );
      }
      return _QuotationDetailError(
        message: state.message,
        onRetry: () => context.read<QuotationDetailCubit>().load(quotationId),
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

    return _content(
      context,
      detail: detail,
      history: history,
      isSubmitting: isSubmitting,
      isCancelling: isCancelling,
      isOfflineDraft: false,
    );
  }

  Widget _content(
    BuildContext context, {
    required QuotationDetail detail,
    required List<QuotationApprovalHistory> history,
    required bool isSubmitting,
    required bool isCancelling,
    required bool isOfflineDraft,
  }) {
    return QuotationDetailContent(
      detail: detail,
      history: history,
      isSubmitting: isSubmitting,
      isCancelling: isCancelling,
      isOfflineDraft: isOfflineDraft,
      onEdit: () => _editQuotation(context, detail),
      onConvertToSalesOrder: () => _convertToSalesOrder(context, detail),
    );
  }
}

class _QuotationDetailError extends StatelessWidget {
  const _QuotationDetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colors.warning),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text('common.retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
