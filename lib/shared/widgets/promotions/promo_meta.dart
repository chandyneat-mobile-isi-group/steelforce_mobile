import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/promotions/promo_tone.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// A promotion's end date, said the way a rep thinks about it.
///
/// The old cards printed "31 Aug 2026" under a "Valid Until" label, which asks
/// the reader to do the arithmetic themselves, standing in a depot yard, to
/// answer the only question that matters: is this still worth mentioning
/// today. This states the answer and keeps the date as the supporting detail.
class PromoCountdown extends StatelessWidget {
  const PromoCountdown({
    super.key,
    required this.promo,
    required this.now,
  });

  final PromoView promo;

  /// Passed in rather than read from `DateTime.now()` here, so `build` has no
  /// hidden clock dependency (FS-PRF-7) and a test can pin the date instead of
  /// going stale the week after it is written.
  final DateTime now;

  /// `ActiveLanguage.code`, not the device locale: the rep picks the app's
  /// language on the splash screen and expects dates to follow it.
  ///
  /// Guarded because `DateFormat.yMMMd('km')` **throws** a `LocaleDataException`
  /// when the symbols have not been loaded — it does not degrade to English.
  /// `AppBootstrapService` loads them, so the throw only happens where boot did
  /// not run, but the consequence there is the whole card failing to build over
  /// a supporting date. Same guard as `profile_info_section.dart`.
  String _formatEndDate(DateTime date) {
    try {
      return DateFormat.yMMMd(ActiveLanguage.code).format(date);
    } catch (_) {
      return DateFormat.yMMMd().format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgency = promo.urgency(now);
    final color = promoUrgencyColor(context, urgency);
    final days = promo.daysLeft(now);

    final headline = switch (urgency) {
      PromoUrgency.expired => 'promotions.expiry.ended'.tr,
      _ => switch (days) {
          0 => 'promotions.expiry.ends_today'.tr,
          1 => 'promotions.expiry.ends_tomorrow'.tr,
          _ => 'promotions.expiry.ends_in_days'.trParams({'days': '$days'}),
        },
    };

    final date = _formatEndDate(promo.endsOn);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Nudged down to sit on the first text line rather than centred on a
          // block that grows to two lines in Khmer (FS-LOC-4).
          padding: EdgeInsets.only(top: context.rh(1)),
          child: Icon(
            urgency == PromoUrgency.expired
                ? Icons.history_rounded
                : Icons.schedule_rounded,
            size: context.rr(14),
            color: color,
          ),
        ),
        SizedBox(width: context.rw(6)),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: headline,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '  ·  $date',
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
              ],
            ),
            style: TextStyle(fontSize: context.rsp(11.5), height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// One labelled fact about a promotion — category, depots, minimum spend.
///
/// Rendered as a chip inside a [Wrap] rather than the old row of three
/// `Expanded` columns. On a 390pt phone that row gave each item about 100pt,
/// so "All Structural Steel" ellipsized to "All Structu…" — the field said
/// nothing while still taking a third of the width. Wrapping costs a line and
/// keeps the value.
class PromoMetaChip extends StatelessWidget {
  const PromoMetaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;

  /// What the value means, e.g. "Applies to". Read by screen readers; drawn
  /// only as the icon's tooltip, because on a card this dense the label costs
  /// more room than it earns.
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(8),
          vertical: context.rh(5),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(context.rr(8)),
          border: Border.all(color: colors.border),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(right: context.rw(5)),
                  child:
                      Icon(icon, size: context.rr(12), color: colors.iconMuted),
                ),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The approval / validity state, as an icon-and-text chip.
///
/// Icon-bearing because status is exactly the case where colour alone is not
/// enough (FS-A11Y-3) — and because "green pill" and "amber pill" are
/// indistinguishable to a rep glancing at a phone in direct sun.
class PromoStatusChip extends StatelessWidget {
  const PromoStatusChip({super.key, required this.status});

  final PromoStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = promoStatusTone(context, status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(4),
      ),
      decoration: BoxDecoration(
        color: tone.surfaceOn(context),
        borderRadius: BorderRadius.circular(context.rr(20)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(right: context.rw(4)),
                child:
                    Icon(tone.icon, size: context.rr(12), color: tone.accent),
              ),
            ),
            TextSpan(
              text: tone.labelKey.tr,
              style: TextStyle(
                color: tone.accent,
                fontSize: context.rsp(10.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
