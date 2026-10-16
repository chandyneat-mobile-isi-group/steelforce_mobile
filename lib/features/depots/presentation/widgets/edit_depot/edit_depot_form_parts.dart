import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// A small icon-and-title heading over a group of edit-sheet fields.
class EditDepotSectionTitle extends StatelessWidget {
  const EditDepotSectionTitle(
      {super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(icon, size: context.rr(16), color: colors.textSecondary),
        SizedBox(width: context.rw(6)),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(13),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// An outlined edit-sheet field that greys out when the depot is read-only.
class EditDepotTextField extends StatelessWidget {
  const EditDepotTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: context.rsp(14),
        color: enabled ? colors.textPrimary : colors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: enabled ? colors.card : colors.surfaceSoft,
        labelStyle: TextStyle(
          fontSize: context.rsp(13),
          color: colors.textSecondary,
        ),
        hintStyle: TextStyle(
          fontSize: context.rsp(13),
          color: colors.textSecondary.withValues(alpha: 0.6),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.rw(14),
          vertical: context.rh(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// The depot's captured coordinates, shown but not editable here.
class DepotGpsTile extends StatelessWidget {
  const DepotGpsTile({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gps_fixed_rounded,
            size: context.rr(18),
            color: scheme.primary,
          ),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text(
              'GPS: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
              style: TextStyle(
                fontSize: context.rsp(12),
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
