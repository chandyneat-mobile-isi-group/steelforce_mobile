import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// An icon + wrapped text line in one colour, used on Sync Center quotation
/// cards for the admin document, the admin's reason, and sync errors.
class PendingSyncInfoLine extends StatelessWidget {
  const PendingSyncInfoLine({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: context.rr(14), color: color),
        SizedBox(width: context.rw(6)),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: context.rsp(11.5), height: 1.3)),
        ),
      ],
    );
  }
}
