import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_quotation_details_cubit.dart';
import 'package:steelforce/features/order/presentation/l10n/quotation_sync_status_l10n.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';
import 'package:steelforce/shared/widgets/sheet_close_button.dart';
import 'package:steelforce/shared/widgets/info_section_card.dart';

/// Opens what a quotation waiting in the sync queue holds — read from the
/// device, so it works offline.
Future<void> showPendingQuotationDetails(
  BuildContext context,
  SyncQueueItem item,
) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => sl<PendingQuotationDetailsCubit>()..load(item.quotationId),
      child: PendingQuotationDetailsSheet(item: item),
    ),
  );
}

class PendingQuotationDetailsSheet extends StatelessWidget {
  const PendingQuotationDetailsSheet({super.key, required this.item});

  final SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    // The brand pattern fills behind; the content sets the sheet height.
    return Stack(
      children: [
        const Positioned.fill(
          // Subtle, not vivid: this sheet's text sits on it directly,
          // and grey or dark text is unreadable on the vivid blue.
          child: BrandWallpaperBackground(style: BrandWallpaperStyle.subtle),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.rw(16),
            context.rh(4),
            context.rw(16),
            context.rh(16),
          ),
          child: BlocBuilder<PendingQuotationDetailsCubit,
              PendingQuotationDetailsState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(item: item, quotation: _quotationOf(state)),
                SizedBox(height: context.rh(12)),
                ...switch (state) {
                  PendingQuotationDetailsLoading() => [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: context.rh(32)),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  PendingQuotationDetailsLoaded(:final quotation) =>
                    _sections(context, quotation),
                  PendingQuotationDetailsNotFound() => [
                      _Message(
                        icon: Icons.inventory_2_outlined,
                        text: 'sync_center.quotation.detail.not_on_device'.tr,
                      ),
                    ],
                  PendingQuotationDetailsFailure() => [
                      _Message(
                        icon: Icons.error_outline_rounded,
                        text: 'sync_center.quotation.detail.load_failed'.tr,
                        onRetry: () => context
                            .read<PendingQuotationDetailsCubit>()
                            .load(item.quotationId),
                      ),
                    ],
                },
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Quotation? _quotationOf(PendingQuotationDetailsState s) =>
      s is PendingQuotationDetailsLoaded ? s.quotation : null;

  List<Widget> _sections(BuildContext context, Quotation q) {
    final money = NumberFormat.currency(
      locale: context.languageCode,
      symbol: r'$',
    );
    final date = DateFormat('d MMM y, HH:mm', context.languageCode);
    final remote = item.remoteNumber;
    return [
      InfoSectionCard(
        icon: Icons.info_outline_rounded,
        title: 'sync_center.detail.information'.tr,
        children: [
          _Row(
            label: 'sync_center.quotation.detail.saved_at'.tr,
            value: date.format(q.createdAt.toLocal()),
          ),
          _Row(
            label: 'sync_center.quotation.detail.valid_until'.tr,
            value: DateFormat('d MMM y', context.languageCode)
                .format(q.validUntil.toLocal()),
          ),
          if (remote != null && remote.isNotEmpty)
            _Row(
              label: 'sync_center.quotation.detail.admin_number'.tr,
              value: remote,
            ),
          if (item.attemptCount > 0)
            _Row(
              label: 'sync_center.depot.detail.attempts'.tr,
              value: '${item.attemptCount}',
            ),
        ],
      ),
      SizedBox(height: context.rh(12)),
      InfoSectionCard(
        icon: Icons.list_alt_rounded,
        title: 'sync_center.quotation.detail.items'.tr,
        count: q.lines.length,
        children: [
          if (q.lines.isEmpty)
            Text(
              'sync_center.quotation.detail.no_items'.tr,
              style: TextStyle(color: context.appColors.textSecondary),
            ),
          for (final (i, line) in q.lines.indexed) ...[
            if (i > 0) Divider(height: context.rh(16)),
            _LineRow(line: line, money: money),
          ],
        ],
      ),
      SizedBox(height: context.rh(12)),
      InfoSectionCard(
        icon: Icons.calculate_outlined,
        title: 'sync_center.quotation.detail.totals'.tr,
        children: [
          _Row(
            label: 'sync_center.quotation.detail.subtotal'.tr,
            value: money.format(q.subtotal),
          ),
          if (q.discount != 0)
            _Row(
              label: 'sync_center.quotation.detail.discount'.tr,
              value: '− ${money.format(q.discount)}',
            ),
          if (q.tax != 0)
            _Row(
              label: 'sync_center.quotation.detail.tax'.tr,
              value: money.format(q.tax),
            ),
          _Row(
            label: 'sync_center.quotation.detail.total'.tr,
            value: money.format(q.total),
            emphasis: true,
          ),
        ],
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, required this.quotation});

  final SyncQueueItem item;
  final Quotation? quotation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final shop = quotation?.shopName ?? item.shopName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'sync_center.quotation.detail.title'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(12),
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: context.rh(4)),
                  Text(
                    shop?.isNotEmpty == true
                        ? shop!
                        : 'sync.quotation_ref'
                            .trParams({'id': item.quotationId}),
                    style: TextStyle(
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SheetCloseButton(),
          ],
        ),
        SizedBox(height: context.rh(8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rw(10),
            vertical: context.rh(4),
          ),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.status.localizedLabel,
            style: TextStyle(
              color: scheme.primary,
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.money});

  final CartItem line;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final product = line.product;
    final name = product.displayName.isEmpty
        ? product.materialCode
        : context.localized(product.displayName);
    final total = line.lineTotalOrNull;
    final qty =
        NumberFormat.decimalPattern(context.languageCode).format(line.quantity);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: context.rsp(13.5),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  height: 1.3,
                ),
              ),
              SizedBox(height: context.rh(2)),
              Text(
                [
                  '$qty ${line.unit}',
                  if (line.unitPriceOrNull != null)
                    '× ${money.format(line.unitPriceOrNull)}',
                  if (line.discountPercent > 0)
                    '−${line.discountPercent.toStringAsFixed(0)}%',
                ].join('  '),
                style: TextStyle(
                  fontSize: context.rsp(12),
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.rw(12)),
        Text(
          total == null
              ? 'sync_center.quotation.detail.price_pending'.tr
              : money.format(total),
          style: TextStyle(
            fontSize: context.rsp(13.5),
            fontWeight: FontWeight.w800,
            color: total == null ? colors.textSecondary : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// One label/value line. Wraps rather than clips: Khmer runs longer.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(13.5),
                color: emphasis ? scheme.onSurface : colors.textSecondary,
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          SizedBox(width: context.rw(12)),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: context.rsp(emphasis ? 15 : 13.5),
              fontWeight: FontWeight.w800,
              color: emphasis ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(24)),
      child: Column(
        children: [
          Icon(icon, size: context.rr(32), color: colors.iconMuted),
          SizedBox(height: context.rh(8)),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
          if (onRetry != null) ...[
            SizedBox(height: context.rh(8)),
            TextButton(onPressed: onRetry, child: Text('common.retry'.tr)),
          ],
        ],
      ),
    );
  }
}
