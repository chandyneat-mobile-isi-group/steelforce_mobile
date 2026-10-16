import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/promotions/promo_tone.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// The number the rep says out loud, given the most weight on the card.
///
/// The old cards buried it: the type badge ("ON-INVOICE") took the prominent
/// left slot and the rate sat in a small amber pill in the top-right corner. A
/// rep scanning a list is looking for the rate, so the rate leads and the
/// mechanism becomes a quiet label under it.
///
/// Sized by its content rather than the old fixed `width: 90`. That width fits
/// "2.00%" at 100% text scale and clips it at 200% (FS-A11Y-2); a minimum width
/// keeps a column of tiles aligned without capping any of them.
class PromoValueTile extends StatelessWidget {
  const PromoValueTile({
    super.key,
    required this.value,
    required this.tone,
    this.dimmed = false,
  });

  final PromoValue value;
  final PromoTone tone;

  /// Drains the colour for a promotion that can no longer be quoted, so an
  /// expired card reads as inactive at a glance instead of competing with the
  /// live ones for attention.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final accent = dimmed ? Theme.of(context).disabledColor : tone.accent;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: context.rw(88)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(12),
          vertical: context.rh(12),
        ),
        decoration: BoxDecoration(
          color: dimmed ? Colors.transparent : tone.surfaceOn(context),
          borderRadius: BorderRadius.circular(context.rr(12)),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: _content(context, accent),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, Color accent) {
    switch (value) {
      case PromoPercent(:final percent):
        return [
          _Figure(
            // Two decimals because depot rates are negotiated at 1.50% and
            // 1.75%; rounding those to "2%" misquotes the depot.
            text: percent.toStringAsFixed(2),
            suffix: '%',
            color: accent,
          ),
          _Caption('promotions.value.discount'.tr, accent),
        ];

      case PromoAmount(:final amount, :final per):
        return [
          _Figure(text: amount, color: accent),
          _Caption(
            per == null
                ? 'promotions.value.rebate'.tr
                : 'promotions.value.per_unit'.trParams({'unit': per}),
            accent,
          ),
        ];

      case PromoBuyGet(:final buy, :final get, :final unit):
        // Read as an exchange rather than two numbers, because that is the
        // sentence the rep has to say: "buy forty, get three".
        return [
          _Caption('promotions.buy_get.buy'.tr, accent),
          _Figure(text: '$buy', color: accent),
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.rh(2)),
            child: Icon(
              Icons.south_rounded,
              size: context.rr(14),
              color: accent.withValues(alpha: 0.7),
            ),
          ),
          _Caption('promotions.buy_get.get_free'.tr, accent),
          _Figure(text: '$get', color: accent),
          _Caption(unit, accent),
        ];

      case PromoTerms(:final text):
        return [
          Icon(Icons.handshake_rounded, size: context.rr(22), color: accent),
          SizedBox(height: context.rh(4)),
          _Caption(text, accent),
        ];
    }
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.color, this.suffix});

  final String text;
  final String? suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: context.rsp(21),
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        if (suffix != null)
          Text(
            suffix!,
            style: TextStyle(
              color: color,
              fontSize: context.rsp(13),
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        // 0.85 rather than a second token: the caption must stay legibly the
        // same hue as the figure it belongs to, and a separate muted colour
        // broke that pairing on the dark card.
        color: color.withValues(alpha: 0.85),
        fontSize: context.rsp(9.5),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        height: 1.2,
      ),
    );
  }
}
