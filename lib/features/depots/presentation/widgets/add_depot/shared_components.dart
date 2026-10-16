part of '../add_depot_bottom_sheet.dart';

extension SharedComponentsExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // Shared field widgets — same look as before, now error-aware
  // ===========================================================================
  Widget _gap([double height = 10]) => SizedBox(height: _spacing(height));

  Widget _twoCol(Widget left, Widget right,
      {int flexLeft = 1, int flexRight = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexLeft, child: left),
        SizedBox(width: _spacing(8)),
        Expanded(flex: flexRight, child: right),
      ],
    );
  }

  Widget _label(String label, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: _fontSize(13),
              fontWeight: FontWeight.w700,
            ),
            children: required
                ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: _fontSize(13),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ]
                : null,
          ),
        ),
      );

  /// Sub-label under a field. Used where the SAP meaning of a field is not
  /// guessable from its name — a rep cannot be expected to know that
  /// "Search Term 1" is the place and "Search Term 2" is the shop.
  Widget _hint(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(
          msg,
          style: TextStyle(
            color: context.appColors.textSecondary.withValues(alpha: 0.7),
            fontSize: _fontSize(11),
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _errorText(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(
          msg,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: _fontSize(11),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildIconBox(IconData icon,
      {double size = 32, double iconSize = 18}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _inputCard({
    required Widget child,
    String? label,
    IconData? icon,
    bool required = false,
    bool compact = false,
    String? error,
  }) {
    final hasError = error != null;
    final card = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isTablet ? 14 : context.rw(10),
        vertical: widget.isTablet ? 10 : context.rh(8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? Theme.of(context).colorScheme.error
              : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null || icon != null)
                  Row(
                    children: [
                      if (icon != null) ...[
                        _buildIconBox(icon, size: 24, iconSize: 14),
                        const SizedBox(width: 6),
                      ],
                      if (label != null)
                        Expanded(
                          child: _cardLabel(label,
                              required: required, fontSize: 12),
                        ),
                    ],
                  ),
                if (label != null || icon != null) const SizedBox(height: 5),
                child,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  _buildIconBox(icon, size: 30, iconSize: 16),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (label != null) ...[
                        _cardLabel(label, required: required, fontSize: 13),
                        const SizedBox(height: 4),
                      ],
                      child,
                    ],
                  ),
                ),
              ],
            ),
    );

    if (hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          card,
          _errorText('add_depot.$error'.tr),
        ],
      );
    }
    return card;
  }

  Widget _cardLabel(String label,
          {bool required = false, double fontSize = 13}) =>
      RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: _fontSize(fontSize),
            fontWeight: FontWeight.w700,
          ),
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: _fontSize(fontSize),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ]
              : null,
        ),
      );

  InputDecoration _decoration(String hint,
      {String? error, bool readOnly = false, Widget? suffixIcon}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c),
        );

    return InputDecoration(
      isDense: true,
      hintText: hint,
      counterText: '',
      hintStyle: TextStyle(
        color: const Color(0xFF94A3B8),
        fontSize: _fontSize(12),
      ),
      filled: true,
      fillColor: readOnly
          ? context.appColors.border.withValues(alpha: 0.2)
          : const Color(0xFFF8FAFC),
      contentPadding: EdgeInsets.symmetric(
        horizontal: widget.isTablet ? 12 : context.rw(10),
        vertical: widget.isTablet ? 10 : context.rh(7),
      ),
      suffixIcon: suffixIcon,
      enabledBorder: border(
        error != null
            ? Theme.of(context).colorScheme.error
            : const Color(0xFFE2E8F0),
      ),
      focusedBorder: border(Theme.of(context).colorScheme.primary),
      errorBorder: border(Theme.of(context).colorScheme.error),
      focusedErrorBorder: border(Theme.of(context).colorScheme.error),
    );
  }

  Widget _text(
    TextEditingController controller,
    String hint, {
    String? label,
    IconData? icon,
    bool required = false,
    bool compact = false,
    String? error,
    int? maxLength,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<String> onChanged,
  }) {
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      inputFormatters: maxLength != null
          ? [LengthLimitingTextInputFormatter(maxLength)]
          : null,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: _fontSize(13),
        fontWeight: FontWeight.w500,
      ),
      decoration: _decoration(hint, error: error),
    );

    if (label != null || icon != null) {
      return _inputCard(
        label: label,
        icon: icon,
        required: required,
        compact: compact,
        error: error,
        child: field,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        if (error != null) _errorText('add_depot.$error'.tr),
      ],
    );
  }
}
