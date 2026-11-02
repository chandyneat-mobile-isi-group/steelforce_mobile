import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// A status pill on a planned visit's Sync Center card.
class PlanSyncChip extends StatelessWidget {
  const PlanSyncChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: context.rsp(10.5),
                fontWeight: FontWeight.w800)),
      );
}

/// One icon-and-text line on a planned visit's Sync Center card.
class PlanSyncLine extends StatelessWidget {
  const PlanSyncLine(this.icon, this.text, {super.key, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.appColors.textSecondary;
    return Padding(
      padding: EdgeInsets.only(top: context.rh(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.rr(14), color: c),
          SizedBox(width: context.rw(6)),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c, fontSize: context.rsp(11.5), height: 1.3)),
          ),
        ],
      ),
    );
  }
}
