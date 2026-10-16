import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/promotions/promo_blocked_note.dart';
import 'package:steelforce/shared/widgets/promotions/promo_code_row.dart';
import 'package:steelforce/shared/widgets/promotions/promo_meta.dart';
import 'package:steelforce/shared/widgets/promotions/promo_tone.dart';
import 'package:steelforce/shared/widgets/promotions/promo_value_tile.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// One promotion, rendered the same way everywhere it appears.
///
/// Both promotion surfaces previously drew their own card — different radii,
/// different shadows, different palettes, a different idea of which field
/// mattered most — so the depot discount a rep read on the visit screen looked
/// like a different kind of object from the same discount on the quotation
/// screen. This is the single card both now use (FS-MNT-6).
///
/// Reading order is deliberate and matches how the card gets used out loud:
/// the rate first, then what it applies to, then how long it lasts, then the
/// code to quote.
class PromoCard extends StatelessWidget {
  const PromoCard({
    super.key,
    required this.promo,
    required this.now,
    this.terms,
    this.onTap,
    this.showCode = true,
  });

  final PromoView promo;

  /// Injected clock — see [PromoCountdown.now].
  final DateTime now;

  /// How the order this card is being read against is set up. Null where there
  /// is no order — the outlet's promotions list — and nothing is then blocked.
  final OrderTerms? terms;

  final VoidCallback? onTap;

  /// Suppressed in dense contexts (the quotation section's rail) where the
  /// card is a summary and the code lives on the detail screen.
  final bool showCode;

  /// The accessibility text scale past which the two-column card stops fitting
  /// on a phone. Measured, not guessed: at 390pt with the app's own type ramp
  /// the body's label rows begin to overflow between 1.3x and 1.5x.
  static const _stackTextScale = 1.4;

  static bool _shouldStack(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(100) / 100 > _stackTextScale;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = promoToneFor(context, promo.kind);
    final blockedBy = promo.unmetRequirement(terms);

    // One `dimmed` treatment for both reasons the card cannot be used: it has
    // run out, or this order does not qualify. They are different facts — the
    // note below says which — but they mean the same thing to a rep scanning
    // the list, so they should not look different.
    final unusable =
        promo.urgency(now) == PromoUrgency.expired || blockedBy != null;

    final card = Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
        // Flat while unusable. The shadow is what lifts a card off the canvas
        // and reads as "live"; keeping it on a blocked promotion would leave it
        // competing with the ones the rep can actually apply.
        boxShadow: unusable ? null : colors.cardShadow,
      ),
      padding: EdgeInsets.all(context.rr(14)),
      child: LayoutBuilder(builder: (context, constraints) {
        final shouldStack = _shouldStack(context) || constraints.maxWidth < 280;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Side by side normally; stacked once the system font is scaled up
            // or the card is constrained by a multi-column layout.
            if (shouldStack)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PromoValueTile(
                      value: promo.value, tone: tone, dimmed: unusable),
                  SizedBox(height: context.rh(10)),
                  _Body(promo: promo, now: now, tone: tone),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PromoValueTile(
                      value: promo.value, tone: tone, dimmed: unusable),
                  SizedBox(width: context.rw(12)),
                  Expanded(child: _Body(promo: promo, now: now, tone: tone)),
                ],
              ),
            if (blockedBy != null) ...[
              SizedBox(height: context.rh(10)),
              PromoBlockedNote(requirement: blockedBy),
            ],
            if (showCode && promo.code != null) ...[
              SizedBox(height: context.rh(12)),
              Divider(height: 1, color: colors.divider),
              SizedBox(height: context.rh(6)),
              PromoCodeRow(code: promo.code!),
            ],
          ],
        );
      }),
    );

    if (onTap == null || blockedBy != null) {
      return Semantics(
          container: true, enabled: blockedBy == null, child: card);
    }

    return Semantics(
      container: true,
      button: true,
      child: PressScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        pressedScale: AppScale.pressedCard,
        child: card,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.promo, required this.now, required this.tone});

  final PromoView promo;
  final DateTime now;
  final PromoTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          promo.title,
          // Two lines, not one: Khmer runs roughly a third longer than the
          // English and does not break on spaces (FS-LOC-4), so a single-line
          // title truncates the product category out of exactly the strings a
          // Khmer-reading rep needs.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(14.5),
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        SizedBox(height: context.rh(5)),
        // Mechanism and status sit together on a wrapping line rather than the
        // status floating opposite the title. Two reasons: they are the same
        // kind of fact and read better as a pair, and a `Row` holding a title
        // against an unbounded chip overflows to the right the moment the
        // system font scale goes up (FS-A11Y-2) — a Wrap moves the chip onto
        // its own line instead.
        Wrap(
          spacing: context.rw(8),
          runSpacing: context.rh(4),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tone.icon, size: context.rr(12), color: tone.accent),
                SizedBox(width: context.rw(4)),
                // Flexible so the label wraps inside its Wrap slot. A `Wrap`
                // constrains each child to the run width but does not make it
                // shrink, so a min-sized Row wider than the card overflows.
                Flexible(
                  child: Text(
                    tone.labelKey.tr,
                    style: TextStyle(
                      color: tone.accent,
                      fontSize: context.rsp(10.5),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            PromoStatusChip(status: promo.status),
          ],
        ),
        if (promo.summary != null) ...[
          SizedBox(height: context.rh(6)),
          Text(
            promo.summary!,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12),
              height: 1.4,
            ),
          ),
        ],
        SizedBox(height: context.rh(10)),
        PromoCountdown(promo: promo, now: now),
        if (_hasMeta) ...[
          SizedBox(height: context.rh(8)),
          Wrap(
            spacing: context.rw(6),
            runSpacing: context.rh(6),
            children: [
              if (promo.category != null)
                PromoMetaChip(
                  icon: Icons.category_rounded,
                  label: 'promotions.meta.applies_to'.tr,
                  value: promo.category!,
                ),
              if (promo.depots != null)
                PromoMetaChip(
                  icon: Icons.storefront_rounded,
                  label: 'promotions.meta.depots'.tr,
                  value: promo.depots!,
                ),
              if (promo.minSpend != null)
                PromoMetaChip(
                  icon: Icons.shopping_bag_rounded,
                  label: 'promotions.meta.min_spend'.tr,
                  value: promo.minSpend!,
                ),
            ],
          ),
        ],
      ],
    );
  }

  bool get _hasMeta =>
      promo.category != null || promo.depots != null || promo.minSpend != null;
}
