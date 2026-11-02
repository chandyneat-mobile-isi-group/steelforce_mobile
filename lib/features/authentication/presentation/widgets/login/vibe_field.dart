import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

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

/// The sign-in look: a rounded pill in navy ink ([AuthInk]) on a pale fill,
/// for the forms on the white brand backdrop. The same ink whatever the
/// theme: the auth screens are always light ([AuthLightTheme]).
///
/// The label sits inside the pill as its placeholder and never floats — the
/// pill has no border gap to float into — but it is still the field's label,
/// so a screen reader announces "Phone Number", not an empty edit box.
InputDecoration photoFieldDecoration(
  BuildContext context, {
  required String label,
  IconData? icon,
  Widget? suffix,
  bool required = false,
}) {
  const ink = AuthInk.text;
  final muted = ink.withValues(alpha: 0.72);
  final radius = BorderRadius.circular(context.rr(28));
  OutlineInputBorder edge(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: c, width: w),
      );

  final labelStyle = TextStyle(
    color: muted,
    fontSize: context.rsp(16),
    height: AppTypography.compactLineHeight,
  );
  return InputDecoration(
    labelText: required ? null : label,
    // A required field marks itself like the themed fields do: a red star.
    label: required
        ? Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AuthInk.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            style: labelStyle,
          )
        : null,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    labelStyle: labelStyle,
    prefixIcon: icon == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(
                start: context.rw(14), end: context.rw(6)),
            child: Icon(icon, color: muted, size: context.rr(22)),
          ),
    prefixIconConstraints: BoxConstraints(minWidth: context.rr(48)),
    suffixIcon: suffix,
    filled: true,
    fillColor: AuthInk.fieldFill,
    // A lit-blue outline, as in the approved artwork; strong enough to hold
    // in sunlight.
    border: edge(AuthInk.fieldBorder),
    enabledBorder: edge(AuthInk.fieldBorder),
    focusedBorder: edge(AuthInk.accent, 1.6),
    errorBorder: edge(AuthInk.error),
    focusedErrorBorder: edge(AuthInk.error, 1.6),
    errorStyle: TextStyle(color: AuthInk.error, fontSize: context.rsp(12)),
    // Room for a two-line Khmer error without the field jumping wider.
    errorMaxLines: 2,
    contentPadding: EdgeInsets.symmetric(
      horizontal: context.rw(20),
      vertical: context.rh(17),
    ),
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

  /// Draw with [photoFieldDecoration] (the sign-in pill, navy ink) instead
  /// of the filled box.
  final bool onPhoto;

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
    this.onPhoto = false,
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
    final fill = isDark ? AuthInk.hairline : AuthInk.hairline;

    if (onPhoto) {
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
          color: AuthInk.text,
          fontSize: context.rsp(16),
          height: AppTypography.compactLineHeight,
        ),
        cursorColor: AuthInk.text,
        decoration: photoFieldDecoration(
          context,
          label: label,
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
