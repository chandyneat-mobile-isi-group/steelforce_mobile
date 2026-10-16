import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';

/// A titled settings block — the card shape shared by Appearance, Language, and
/// any future single-row setting on the Profile screen.
///
/// ## Why this exists
///
/// `AppearanceSection` and `LanguageSection` were built as separate copies of
/// the same layout, and they drifted: one sized its type with the responsive
/// helpers (`context.rsp`), the other hand-rolled `isTablet ? 18 : 14.5`
/// ladders. Same card, same row, different numbers — so the two blocks rendered
/// at visibly different type and padding on every device whose width was not
/// exactly the 390pt design baseline, and inverted at `medium` where `rsp`
/// scales past the hardcoded tablet value.
///
/// Consistency here is not a style preference: these blocks sit directly on top
/// of each other, so any drift between them is the most visible kind.
/// One widget, two call sites, no way to drift again.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  /// Section heading, already translated.
  final String title;

  /// Rows inside the card — normally one or more [SettingsRow]s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: EdgeInsets.fromLTRB(
        context.rw(18),
        context.rh(16),
        context.rw(12),
        context.rh(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: context.rsp(14.5),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: context.rh(4)),
          ...children,
        ],
      ),
    );
  }
}

/// One tappable settings row: leading icon, label, current value, chevron.
///
/// Every dimension goes through the responsive helpers, so a row grows with the
/// window on exactly the curve documented in `ResponsiveSizing` — never on a
/// second, hand-tuned one.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.valuePrefix,
  });

  final IconData icon;
  final String label;

  /// The current selection, shown before the chevron.
  final String value;

  /// Optional widget between label and [value] — the language flag, today.
  final Widget? valuePrefix;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(10)),
        child: Row(
          children: [
            Icon(icon, size: context.rr(20), color: scheme.primary),
            SizedBox(width: context.rw(12)),
            // Expanded rather than Spacer: Khmer labels run longer than their
            // English counterparts and the type scale grows faster than the box
            // scale, so the label — not the value — is what needs the slack.
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: context.rsp(13.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (valuePrefix != null) ...[
              valuePrefix!,
              SizedBox(width: context.rw(6)),
            ],
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: context.rw(4)),
            Icon(Icons.chevron_right_rounded,
                size: context.rr(20), color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
