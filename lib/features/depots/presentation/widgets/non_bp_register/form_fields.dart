part of '../non_bp_depot_register_screen.dart';

/// Says the screen is a demo, once, at the top.
class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: context.rr(16),
            color: scheme.primary,
          ),
          SizedBox(width: context.rw(8)),
          Expanded(
            child: Text(
              'Demo screen. Nothing entered here is saved or sent to SAP.',
              style: TextStyle(
                fontSize: context.rsp(11.5),
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: context.rsp(11),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        color: context.appColors.textPrimary,
      ),
    );
  }
}

/// A labelled text field matching the create-depot form's decoration.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                ),
              ),
          ],
        ),
        SizedBox(height: context.rh(6)),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          style: TextStyle(
            fontSize: context.rsp(14),
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: TextStyle(
              fontSize: context.rsp(10.5),
              color: colors.textSecondary,
            ),
            hintStyle: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.3),
              fontSize: context.rsp(14),
            ),
            filled: true,
            fillColor: colors.surfaceSoft,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.rw(14),
              vertical: context.rh(14),
            ),
            enabledBorder: border(colors.border),
            focusedBorder: border(scheme.onSurface),
            errorBorder: border(scheme.error),
            focusedErrorBorder: border(scheme.error),
          ),
        ),
      ],
    );
  }
}

/// Picks what kind of party this is.
class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.selected, required this.onChanged});

  final NonBpDepotKind selected;
  final ValueChanged<NonBpDepotKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: TextStyle(
            fontSize: context.rsp(12),
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: context.rh(8)),
        Wrap(
          spacing: context.rw(8),
          runSpacing: context.rh(8),
          children: [
            for (final kind in NonBpDepotKind.values)
              InkWell(
                onTap: () => onChanged(kind),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(12),
                    vertical: context.rh(8),
                  ),
                  decoration: BoxDecoration(
                    color:
                        kind == selected ? scheme.primary : colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: kind == selected ? scheme.primary : colors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        kind.icon,
                        size: context.rr(14),
                        color: kind == selected
                            ? scheme.onPrimary
                            : colors.textSecondary,
                      ),
                      SizedBox(width: context.rw(6)),
                      Text(
                        kind.label,
                        style: TextStyle(
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w700,
                          color: kind == selected
                              ? scheme.onPrimary
                              : colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
