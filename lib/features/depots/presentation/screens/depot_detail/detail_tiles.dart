part of '../depot_detail_screen.dart';

class _CompactTile extends StatelessWidget {
  const _CompactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    this.onTap,
    this.valueMaxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final VoidCallback? onTap;

  /// One line for a code or a date; more for a value as long as an address.
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // In the saved document: the whole value, and nothing looks tappable.
    final document = _DocumentMode.of(context);
    final onTap = document ? null : this.onTap;

    return InkWell(
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.rh(9)),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: context.rr(18), color: colors.textSecondary),
            SizedBox(width: context.rw(10)),
            // Flexible: a long Khmer label wraps instead of pushing the row
            // past the edge of a small phone.
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(12),
                ),
              ),
            ),
            SizedBox(width: context.rw(10)),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: document ? null : valueMaxLines,
                overflow: document ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  color: onTap != null
                      ? Theme.of(context).colorScheme.primary
                      : colors.textPrimary,
                  fontSize: context.rsp(12.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: context.rw(4)),
              Icon(
                Icons.chevron_right_rounded,
                size: context.rr(16),
                color: colors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(3),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.rr(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: context.rsp(10.5),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A round icon over its label, for the header card's action row.
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final action = onTap;
    final color = action == null ? context.appColors.textSecondary : this.color;
    return InkWell(
      onTap: action == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              action();
            },
      borderRadius: BorderRadius.circular(context.rr(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(8), vertical: context.rh(4)),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.rr(8)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: context.rr(18)),
            ),
            SizedBox(height: context.rh(3)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(11),
                color: context.appColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
