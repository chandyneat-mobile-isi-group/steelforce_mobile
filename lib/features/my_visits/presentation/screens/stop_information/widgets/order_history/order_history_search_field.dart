import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The search box over the order list.
class OrderHistorySearchField extends StatelessWidget {
  const OrderHistorySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.rr(12)),
      borderSide: BorderSide(color: colors.border),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: context.rsp(13.5),
      ),
      decoration: InputDecoration(
        hintText: 'Search Order ID or SAP Doc No...',
        hintStyle: TextStyle(
          color: colors.textHint,
          fontSize: context.rsp(13),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: colors.textSecondary,
          size: context.rr(20),
        ),
        filled: true,
        fillColor: colors.card,
        contentPadding: EdgeInsets.symmetric(
          vertical: context.rh(12),
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
