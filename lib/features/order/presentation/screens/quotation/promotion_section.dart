import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotion_detail_screen.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/promotions_mock_data.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/promo_quotation_preview_card.dart';

import 'package:steelforce/shared/widgets/promotions/promo_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// The promotions block inside the quotation builder.
///
/// Rebuilt around what the rep is doing here. They came to this screen to build
/// a quote; promotions are the supporting information they check on the way
/// past. The previous version rendered all four groups fully expanded —
/// thirteen promotions, a horizontal rail, roughly 700 vertical points of
/// content — in the middle of the form, so the rep scrolled through the entire
/// promotions catalogue every time they wanted the cart below it.
///
/// So: one collapsible block that states what is available in a line, and opens
/// to a **preview per group** (the one expiring soonest) with a link to the
/// rest. That is progressive disclosure (FS-UX-4) rather than a wall, and it
/// leaves the section's total height roughly one screen instead of three.
class PromotionSectionWidget extends StatefulWidget {
  const PromotionSectionWidget({
    super.key,
    this.depotId,
    this.groups,
    this.now,
    this.terms,
    this.initiallyExpanded = true,
  });

  /// The depot this quotation is for, used to fetch their incentives from
  /// `GET /depots/{id}/incentives?shipment=`.
  final String? depotId;

  /// Injectable so a test — and later the repository — supplies the data.
  final List<PromoGroup>? groups;

  /// Injectable clock; see `PromoCountdown.now`.
  final DateTime? now;

  /// How the quotation is currently set up. Rebuilt from the parent's state, so
  /// changing the shipment method re-evaluates every promotion here — which is
  /// the whole point: the COD / Pickup discount is only earned by collecting,
  /// and a rep switching to Delivery must not still see it as money in hand.
  final OrderTerms? terms;

  /// Open by default: a rep who has never seen the section should not have to
  /// discover it. Once they fold it, it stays folded for the rest of the quote.
  final bool initiallyExpanded;

  @override
  State<PromotionSectionWidget> createState() => _PromotionSectionWidgetState();
}

class _PromotionSectionWidgetState extends State<PromotionSectionWidget> {
  late bool _expanded = widget.initiallyExpanded;
  late final DateTime _now = widget.now ?? DateTime.now();
  late List<PromoGroup> _groups = widget.groups ?? mockQuotationPromoGroups;

  @override
  void initState() {
    super.initState();
    _fetchIncentivesIfNeeded();
  }

  @override
  void didUpdateWidget(PromotionSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groups != null) {
      _groups = widget.groups!;
    } else if (oldWidget.depotId != widget.depotId ||
        oldWidget.terms?.isPickup != widget.terms?.isPickup) {
      _fetchIncentivesIfNeeded();
    }
  }

  Future<void> _fetchIncentivesIfNeeded() async {
    if (widget.groups != null ||
        widget.depotId == null ||
        widget.depotId!.isEmpty) {
      return;
    }
    if (!GetIt.I.isRegistered<GetDepotIncentives>()) {
      return;
    }
    final result = await GetIt.I<GetDepotIncentives>()(
      DepotIncentivesParams(
        depotId: widget.depotId!,
        shipment: widget.terms?.isPickup == true ? 'Pickup' : 'Delivery',
      ),
    );
    if (!mounted) return;
    result.when(
      success: (groups) {
        if (groups.isNotEmpty) {
          setState(() {
            _groups = groups;
          });
        }
      },
      failure: (_) {
        // Keeps fallback mock groups on failure or offline
      },
    );
  }

  Iterable<PromoView> get _available => _groups
      .expand((g) => g.promos)
      .where((p) => p.isAvailableFor(_now, widget.terms));

  /// "Ending soon" is the same seven-day window [PromoView.urgency] calls
  /// urgent, so the summary line and the countdowns inside can never disagree.
  ///
  /// Both counts are over the *available* set. A header that said "13
  /// available" while three of them were greyed out for this order would be
  /// worse than no header — the number is the part a rep repeats to a
  /// depot.
  int get _endingSoon =>
      _available.where((p) => p.urgency(_now) == PromoUrgency.urgent).length;

  int get _total => _available.length;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            expanded: _expanded,
            total: _total,
            endingSoon: _endingSoon,
            onToggle: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
          ),
          // AnimatedSize so the fold reads as the block changing size rather
          // than the page jumping under the rep's thumb (FS-ANI-4, FS-UX-2).
          // The collapsed branch is a zero-height full-width box, not a
          // `shrink`: the block must keep the column's width while it animates
          // or the header snaps narrow for the duration.
          AnimatedSize(
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.rw(12),
                      0,
                      context.rw(12),
                      context.rh(12),
                    ),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final groups =
                          _groups.where((g) => g.promos.isNotEmpty).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < groups.length; i += 2)
                            Padding(
                              padding: EdgeInsets.only(bottom: context.rh(16)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _GroupBlock(
                                      group: groups[i],
                                      now: _now,
                                      terms: widget.terms,
                                    ),
                                  ),
                                  SizedBox(width: context.rw(12)),
                                  if (i + 1 < groups.length)
                                    Expanded(
                                      child: _GroupBlock(
                                        group: groups[i + 1],
                                        now: _now,
                                        terms: widget.terms,
                                      ),
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.expanded,
    required this.total,
    required this.endingSoon,
    required this.onToggle,
  });

  final bool expanded;
  final int total;
  final int endingSoon;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      expanded: expanded,
      label: 'promotions.section_title'.tr,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.all(context.rr(14)),
          child: Row(
            children: [
              Icon(Icons.local_offer_rounded,
                  size: context.rr(18), color: scheme.primary),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'promotions.section_title'.tr,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(14.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      // Says what is there before it is opened, so folding the
                      // block never hides the fact that something is expiring.
                      endingSoon > 0
                          ? 'promotions.summary_with_urgent'.trParams({
                              'count': '$total',
                              'soon': '$endingSoon',
                            })
                          : 'promotions.summary'.trParams({'count': '$total'}),
                      style: TextStyle(
                        color: endingSoon > 0
                            ? colors.warningAlt
                            : colors.textSecondary,
                        fontSize: context.rsp(11.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: AppDurations.fast,
                curve: AppCurves.standard,
                child: Icon(Icons.expand_more_rounded,
                    size: context.rr(22), color: colors.iconMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One group heading plus its most urgent promotion, and a way to the rest.
class _GroupBlock extends StatefulWidget {
  const _GroupBlock({
    required this.group,
    required this.now,
    required this.terms,
  });

  final PromoGroup group;
  final DateTime now;
  final OrderTerms? terms;

  @override
  State<_GroupBlock> createState() => _GroupBlockState();
}

class _GroupBlockState extends State<_GroupBlock> {
  bool _showQuotationPreview = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final ordered = [...widget.group.promos]
      ..sort((a, b) => a.endsOn.compareTo(b.endsOn));

    final displayCount = ordered.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.group.titleKey.tr,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (displayCount > 1)
              InkWell(
                onTap: () => _openAll(context, ordered),
                borderRadius: BorderRadius.circular(context.rr(8)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(4),
                    vertical: context.rh(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all $displayCount',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: context.rsp(11),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: context.rr(14), color: scheme.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: context.rh(8)),
        LayoutBuilder(builder: (context, constraints) {
          // Give the PromoCard 42% more layout width (1 / 0.7 = 1.428)
          // so that when FittedBox scales it back down to constraints.maxWidth,
          // it is exactly 30% smaller (0.7 scale).
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth / 0.7,
              child: PromoCard(
                promo: ordered.first,
                now: widget.now,
                terms: widget.terms,
                onTap: () => _openAll(context, ordered),
                showCode: false,
              ),
            ),
          );
        }),
        SizedBox(height: context.rh(8)),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showQuotationPreview = !_showQuotationPreview);
            },
            borderRadius: BorderRadius.circular(context.rr(6)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rw(4),
                vertical: context.rh(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _showQuotationPreview
                        ? Icons.visibility_off_outlined
                        : Icons.receipt_long_outlined,
                    size: context.rw(12),
                    color: scheme.primary,
                  ),
                  SizedBox(width: context.rw(4)),
                  Flexible(
                    child: Text(
                      _showQuotationPreview
                          ? 'Hide Preview'
                          : 'Quotation Format Preview',
                      style: TextStyle(
                        fontSize: context.rsp(10.5),
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showQuotationPreview) ...[
          SizedBox(height: context.rh(4)),
          PromoQuotationPreviewCard(promo: ordered.first),
        ],
      ],
    );
  }

  void _openAll(BuildContext context, List<PromoView> promos) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PromotionDetailScreen(
          title: widget.group.titleKey.tr,
          promos: promos,
          now: widget.now,
          terms: widget.terms,
        ),
      ),
    );
  }
}
