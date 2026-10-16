import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// The themed identity of one promotion kind or status: an accent, a surface
/// tint derived from it, an icon, and a translation key.
///
/// It exists so the two promotion screens stop disagreeing. They previously
/// each hardcoded their own palette — `Colors.blue.shade100`, `0xFFE8F5E9`,
/// `Colors.teal.shade100`, `Colors.amber.shade100` — which meant the same
/// on-invoice discount was blue on one screen and green on the other, and every
/// one of those literals is a light-mode value that renders unreadable text on
/// a dark card (`docs/skills/feature-ui-standard.md` FS-VIS-2, FS-VIS-4).
@immutable
class PromoTone {
  const PromoTone({
    required this.accent,
    required this.icon,
    required this.labelKey,
  });

  /// Text, icon, and border colour. Always a theme token, so it resolves in
  /// both themes.
  final Color accent;

  /// Paired with the accent because colour may never be the only carrier of a
  /// meaning (FS-A11Y-3) — and because a rep glances at these in sunlight.
  final IconData icon;

  final String labelKey;

  /// The accent as a background wash. Low alpha over the card rather than a
  /// second opaque token, so it lands correctly on both light and dark cards
  /// without a second palette to keep in sync.
  Color surfaceOn(BuildContext context) => accent.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.10,
      );
}

/// Resolves the tone for a promotion mechanism.
///
/// Icons are all `_rounded`: one family, one weight, per FS-VIS-7.
PromoTone promoToneFor(BuildContext context, PromoKind kind) {
  final colors = context.appColors;
  final scheme = Theme.of(context).colorScheme;

  return switch (kind) {
    // The primary brand blue, because an on-invoice discount is the default,
    // most common scheme — the one the rest of the palette reads against.
    PromoKind.onInvoice => PromoTone(
        accent: scheme.primary,
        icon: Icons.receipt_long_rounded,
        labelKey: 'promotions.kind.on_invoice',
      ),
    PromoKind.paymentTerm => PromoTone(
        accent: colors.info,
        icon: Icons.payments_rounded,
        labelKey: 'promotions.kind.payment_term',
      ),
    PromoKind.volumeTier => PromoTone(
        accent: colors.accentPurple,
        icon: Icons.stacked_line_chart_rounded,
        labelKey: 'promotions.kind.volume_tier',
      ),
    PromoKind.buyXGetY => PromoTone(
        accent: colors.warningAlt,
        icon: Icons.redeem_rounded,
        labelKey: 'promotions.kind.buy_x_get_y',
      ),
    PromoKind.depotRequest => PromoTone(
        accent: colors.brandNavy,
        icon: Icons.storefront_rounded,
        labelKey: 'promotions.kind.depot_request',
      ),
  };
}

/// Resolves the tone for an approval/validity status.
PromoTone promoStatusTone(BuildContext context, PromoStatus status) {
  final colors = context.appColors;

  return switch (status) {
    PromoStatus.active => PromoTone(
        accent: colors.success,
        icon: Icons.check_circle_rounded,
        labelKey: 'promotions.status.active',
      ),
    PromoStatus.approved => PromoTone(
        accent: colors.success,
        icon: Icons.verified_rounded,
        labelKey: 'promotions.status.approved',
      ),
    // Warning, not error: a request still walking the four approval steps in
    // BRD §8 is the normal path, not a fault.
    PromoStatus.pending => PromoTone(
        accent: colors.warning,
        icon: Icons.hourglass_top_rounded,
        labelKey: 'promotions.status.pending',
      ),
    PromoStatus.expired => PromoTone(
        accent: colors.textDisabled,
        icon: Icons.history_rounded,
        labelKey: 'promotions.status.expired',
      ),
  };
}

/// Resolves the tone the countdown line is drawn in.
///
/// [PromoUrgency.normal] deliberately returns the muted secondary text colour:
/// an end date three months out is a fact, not a warning, and colouring it
/// would spend the rep's attention on the promotions that need it least.
Color promoUrgencyColor(BuildContext context, PromoUrgency urgency) {
  final colors = context.appColors;
  return switch (urgency) {
    PromoUrgency.expired => colors.textDisabled,
    PromoUrgency.urgent => colors.warningAlt,
    PromoUrgency.soon => colors.warning,
    PromoUrgency.normal => colors.textSecondary,
  };
}
