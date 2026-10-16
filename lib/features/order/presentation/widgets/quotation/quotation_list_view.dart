import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_list_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_list_state.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/order_skeletons.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';

class QuotationListView extends StatelessWidget {
  const QuotationListView({
    super.key,
    this.depotId,
  });

  final String? depotId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<QuotationListCubit, QuotationListState>(
      builder: (context, state) {
        if (state is QuotationListInitial || state is QuotationListLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: PendingOrdersSkeleton(),
          );
        }

        if (state is QuotationListError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48, color: colors.warning),
                  const SizedBox(height: 12),
                  Text(
                    state.message,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<QuotationListCubit>().load(refresh: true),
                    child: Text('common.retry'.tr),
                  ),
                ],
              ),
            ),
          );
        }

        final loaded = state as QuotationListLoaded;

        return Column(
          children: [
            // Status Groups Filter Bar (Drafts, Waiting, WithDepot, Won, Closed)
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                children: [
                  _StatusGroupChip(
                    label: 'All',
                    isSelected: loaded.selectedGroup == null,
                    onTap: () =>
                        context.read<QuotationListCubit>().selectGroup(null),
                  ),
                  const SizedBox(width: 8),
                  _StatusGroupChip(
                    label: 'Drafts',
                    isSelected:
                        loaded.selectedGroup == QuotationStatusGroup.drafts,
                    onTap: () => context
                        .read<QuotationListCubit>()
                        .selectGroup(QuotationStatusGroup.drafts),
                  ),
                  const SizedBox(width: 8),
                  _StatusGroupChip(
                    label: 'Waiting',
                    isSelected:
                        loaded.selectedGroup == QuotationStatusGroup.waiting,
                    onTap: () => context
                        .read<QuotationListCubit>()
                        .selectGroup(QuotationStatusGroup.waiting),
                  ),
                  const SizedBox(width: 8),
                  _StatusGroupChip(
                    label: 'With Depot',
                    isSelected:
                        loaded.selectedGroup == QuotationStatusGroup.withDepot,
                    onTap: () => context
                        .read<QuotationListCubit>()
                        .selectGroup(QuotationStatusGroup.withDepot),
                  ),
                  const SizedBox(width: 8),
                  _StatusGroupChip(
                    label: 'Won',
                    isSelected:
                        loaded.selectedGroup == QuotationStatusGroup.won,
                    onTap: () => context
                        .read<QuotationListCubit>()
                        .selectGroup(QuotationStatusGroup.won),
                  ),
                  const SizedBox(width: 8),
                  _StatusGroupChip(
                    label: 'Closed',
                    isSelected:
                        loaded.selectedGroup == QuotationStatusGroup.closed,
                    onTap: () => context
                        .read<QuotationListCubit>()
                        .selectGroup(QuotationStatusGroup.closed),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    context.read<QuotationListCubit>().load(refresh: true),
                child: loaded.quotations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 60, horizontal: 20),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 56,
                                    color: colors.textSecondary
                                        .withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'orders.no_orders'.tr,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: context.rsp(14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount:
                            loaded.quotations.length + (loaded.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == loaded.quotations.length) {
                            context.read<QuotationListCubit>().loadMore();
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final item = loaded.quotations[index];
                          return _QuotationCard(
                            summary: item,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                      name: QuotationDetailScreen.routeName),
                                  builder: (_) => QuotationDetailScreen(
                                    quotationId: item.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusGroupChip extends StatelessWidget {
  const _StatusGroupChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : colors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: isSelected ? scheme.primary : colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? scheme.onPrimary : colors.textPrimary,
            fontSize: context.rsp(12),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _QuotationCard extends StatelessWidget {
  const _QuotationCard({
    required this.summary,
    required this.onTap,
  });

  final QuotationSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    final statusStyle = _resolveStatusStyle(summary.status, theme, colors);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(context.rr(14)),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Document number + Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: context.rsp(16),
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      summary.number.isNotEmpty ? summary.number : summary.id,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(14),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    summary.status,
                    style: TextStyle(
                      color: statusStyle.textColor,
                      fontSize: context.rsp(11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Depot Name
            Text(
              summary.depotName.isNotEmpty
                  ? summary.depotName
                  : 'Depot #${summary.depotId}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(13.5),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Row 3: Items count & Net Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${summary.lineCount} ${summary.lineCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(12),
                  ),
                ),
                Text(
                  PricingText.amount(
                    summary.net,
                    currency: summary.currency ?? 'US3',
                  ),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: context.rsp(16),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (summary.validTo != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: context.rsp(12),
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${'orders.quotation.valid_until'.tr}: ${_formatDate(summary.validTo!)}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
