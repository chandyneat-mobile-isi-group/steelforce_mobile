import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/fade_slide_transition.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/promo_quotation_preview_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_card.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// Every promotion in one group, reached from "See all" on the quotation
/// builder's promotions section.
///
/// It now shows the group it was opened for. Previously it took only a title
/// string and rendered four identical placeholder cards regardless — so the
/// count on the link ("See All (4)") and the list behind it agreed by accident,
/// and tapping any of the four groups produced the same screen.
class PromotionDetailScreen extends StatelessWidget {
  const PromotionDetailScreen({
    super.key,
    required this.title,
    required this.promos,
    this.now,
    this.terms,
  });

  final String title;
  final List<PromoView> promos;

  /// Injectable clock — see `PromoCountdown.now`.
  final DateTime? now;

  /// Carried through from the section so a promotion blocked by the quotation's
  /// shipment method stays blocked here. Arriving on a bigger list is not a way
  /// around the rule.
  final OrderTerms? terms;

  /// Stagger cap, as in the outlet promotions list (FS-ANI-6).
  static const _maxStaggered = 6;

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
        builder: (context) => _build(context, now ?? DateTime.now()),
      );

  Widget _build(BuildContext context, DateTime resolvedNow) {
    final colors = context.appColors;

    // Soonest expiry first: within a single mechanism, the rate is rarely what
    // separates two promotions — the deadline is.
    final ordered = [...promos]..sort((a, b) => a.endsOn.compareTo(b.endsOn));

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme:
            IconThemeData(color: colors.textPrimary, size: context.rr(24)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: context.rh(2)),
            Text(
              'promotions.count'.trParams({'count': '${ordered.length}'}),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentFrame(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              context.rh(8),
              context.pagePadding,
              context.rh(24),
            ),
            itemCount: ordered.length,
            separatorBuilder: (_, __) => SizedBox(height: context.rh(12)),
            itemBuilder: (context, index) => FadeSlideIn(
              key: ValueKey(ordered[index].id),
              delay: AppDurations.stagger * index.clamp(0, _maxStaggered),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PromoCard(
                    promo: ordered[index],
                    now: resolvedNow,
                    terms: terms,
                  ),
                  PromoQuotationPreviewCard(promo: ordered[index]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
