import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class FilterStageHeader extends StatelessWidget {
  const FilterStageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(16),
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: context.rh(3)),
          Text(
            subtitle!,
            style: TextStyle(
                color: colors.textSecondary, fontSize: context.rsp(12)),
          ),
        ],
      ],
    );
  }
}
