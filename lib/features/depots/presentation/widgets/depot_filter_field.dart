import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One full-width dropdown, filled like the search field. "All" (null) is
/// always the first choice; a value no longer offered reads as All rather
/// than breaking the menu.
class DepotFilterField<T> extends StatelessWidget {
  const DepotFilterField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T? value;
  final List<T> options;
  final String Function(T) display;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color));
    return DropdownButtonFormField<T?>(
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      icon:
          Icon(Icons.keyboard_arrow_down_rounded, color: colors.textSecondary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, size: context.rr(18), color: colors.textSecondary),
        filled: true,
        fillColor: colors.surfaceSoft,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.rw(12), vertical: context.rh(12)),
        border: outline(colors.border),
        enabledBorder: outline(colors.border),
        focusedBorder: outline(scheme.primary),
      ),
      style: TextStyle(
          color: colors.textPrimary,
          fontSize: context.rsp(13.5),
          fontWeight: FontWeight.w600),
      items: [
        DropdownMenuItem<T?>(child: Text('depots.filters.any'.tr)),
        for (final option in options)
          DropdownMenuItem<T?>(
            value: option,
            child: Text(display(option), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
