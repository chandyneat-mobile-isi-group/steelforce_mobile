import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The small icon-and-label pill the quotation preview uses for its server
/// status (estimate, approval level) and standing depot agreements.
class QuotationPreviewChip extends StatelessWidget {
  const QuotationPreviewChip({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
    this.fontWeight = FontWeight.w700,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(3),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(context.rr(6)),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rw(11), color: foreground),
          SizedBox(width: context.rw(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: context.rsp(10.5),
              fontWeight: fontWeight,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
