import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/theme/app_colors.dart';

Widget vibeFieldLabel(
  BuildContext context,
  String label, {
  bool required = false,
}) {
  final muted = context.appColors.textSecondary;
  // `height` matters here: without it a Khmer label is clipped in the border
  // gap — see [AppTypography.compactLineHeight].
  final labelStyle = TextStyle(
    color: muted,
    fontSize: context.rsp(15),
    height: AppTypography.compactLineHeight,
  );
  if (!required) {
    return Text(label, style: labelStyle);
  }
  return RichText(
    text: TextSpan(
      style: labelStyle,
      children: [
        TextSpan(text: label),
        TextSpan(
          text: ' *',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

OutlineInputBorder vibeFieldBorder(BuildContext context, Color c,
        [double w = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.rr(AppColors.radius)),
      borderSide: BorderSide(color: c, width: w),
    );

InputDecoration vibeFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  bool required = false,
  IconData? icon,
  Widget? suffix,
}) {
  final scheme = Theme.of(context).colorScheme;
  final colors = context.appColors;
  return InputDecoration(
    label: vibeFieldLabel(context, label, required: required),
    hintText: hint,
    hintStyle: TextStyle(
      color: colors.textSecondary.withValues(alpha: 0.6),
      fontSize: context.rsp(14),
      height: AppTypography.compactLineHeight,
    ),
    // The hint is a full sentence in Khmer and wraps on a narrow handset;
    // without this it is silently truncated mid-word.
    hintMaxLines: 2,
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: colors.textSecondary, size: context.rr(20)),
    suffixIcon: suffix,
    filled: true,
    // The fillColor here is set to transparent in the build method below
    // to allow the BackdropFilter to be visible.
    fillColor: colors.surfaceStrong,
    enabledBorder: vibeFieldBorder(context, colors.border),
    focusedBorder: vibeFieldBorder(context, scheme.secondary, 1.6),
    errorBorder: vibeFieldBorder(context, scheme.error),
    focusedErrorBorder: vibeFieldBorder(context, scheme.error, 1.6),
    errorStyle: TextStyle(color: scheme.error, fontSize: context.rsp(12)),
    contentPadding: EdgeInsets.symmetric(
      horizontal: context.rw(16),
      vertical: context.rh(18),
    ),
  );
}

/// The underline look: no box, a leading icon, and a single line under the
/// text — for a form laid straight onto a dark photo (the sign-in screen).
/// Always light ink, whatever the theme: the surface beneath is always dark.
InputDecoration lineFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  bool required = false,
  IconData? icon,
  Widget? suffix,
}) {
  final error = Theme.of(context).colorScheme.error;
  const ink = Colors.white;
  final muted = ink.withValues(alpha: 0.72);
  UnderlineInputBorder line(Color c, [double w = 1]) =>
      UnderlineInputBorder(borderSide: BorderSide(color: c, width: w));

  return InputDecoration(
    label: DefaultTextStyle.merge(
      style: TextStyle(color: muted),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: label),
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: error, fontWeight: FontWeight.w700),
            ),
        ]),
        style: TextStyle(
          color: muted,
          fontSize: context.rsp(16),
          height: AppTypography.compactLineHeight,
        ),
      ),
    ),
    floatingLabelStyle: TextStyle(color: muted),
    hintText: hint,
    hintStyle: TextStyle(
      color: ink.withValues(alpha: 0.45),
      fontSize: context.rsp(14),
      height: AppTypography.compactLineHeight,
    ),
    hintMaxLines: 2,
    prefixIcon:
        icon == null ? null : Icon(icon, color: muted, size: context.rr(22)),
    prefixIconConstraints: BoxConstraints(minWidth: context.rr(40)),
    suffixIcon: suffix,
    filled: false,
    border: line(ink.withValues(alpha: 0.35)),
    enabledBorder: line(ink.withValues(alpha: 0.35)),
    focusedBorder: line(ink, 1.6),
    errorBorder: line(error),
    focusedErrorBorder: line(error, 1.6),
    // A lighter red than the theme's: the theme error is tuned for white
    // backgrounds and is hard to read on the dark photo.
    errorStyle:
        TextStyle(color: const Color(0xFFFF8A80), fontSize: context.rsp(12)),
    contentPadding: EdgeInsets.symmetric(vertical: context.rh(14)),
  );
}

class VibeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool required;
  final Key? formFieldKey;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// Draw with [lineFieldDecoration] (underline, light ink) instead of the
  /// filled box.
  final bool underline;

  const VibeField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.onSubmitted,
    this.validator,
    this.required = false,
    this.formFieldKey,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.underline = false,
  });

  @override
  Widget build(BuildContext context) {
    // No `BackdropFilter` here, and no `ClipRRect`.
    //
    // Every field used to wrap itself in `ClipRRect` + `BackdropFilter`, but
    // the form already sits inside `GlassCard`, which blurs the whole panel at
    // sigma 15. So each field was applying a *second* blur to an already
    // blurred backdrop — invisible, expensive, and the source of three
    // separate defects:
    //
    //  1. `ClipRRect` cut off the floating label, which `InputDecorator` draws
    //     straddling the top border ("Phone Number" and "Password" were shorn
    //     off at the top).
    //  2. Moving the blur into a `Stack` to free the label then flooded the
    //     console with `!semantics.parentDataDirty` assertions every frame —
    //     nested backdrop filters inside a re-laid-out `Stack`.
    //  3. Both cost a full filter pass per field, per frame.
    //
    // A translucent fill gives the same result against the card's blur, with
    // none of that. The glass look is `GlassCard`'s job, and it already does
    // it.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.22);

    if (underline) {
      return TextFormField(
        key: formFieldKey,
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        style: TextStyle(
          color: Colors.white,
          fontSize: context.rsp(16),
          height: AppTypography.compactLineHeight,
        ),
        cursorColor: Colors.white,
        decoration: lineFieldDecoration(
          context,
          label: label,
          hint: hint,
          required: required,
          icon: icon,
          suffix: suffix,
        ),
      );
    }

    return TextFormField(
      key: formFieldKey,
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: context.rsp(15),
        // A Khmer value stacks diacritics above and below the baseline and
        // clips against the font's own metrics without this.
        height: AppTypography.compactLineHeight,
      ),
      cursorColor: Theme.of(context).colorScheme.secondary,
      decoration: vibeFieldDecoration(
        context,
        label: label,
        hint: hint,
        required: required,
        icon: icon,
        suffix: suffix,
      ).copyWith(fillColor: fill),
    );
  }
}
