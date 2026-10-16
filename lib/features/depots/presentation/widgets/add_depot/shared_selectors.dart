part of '../add_depot_bottom_sheet.dart';

/// Phone, dropdown and segmented inputs. Split out of shared_components.dart for size.
extension _SharedSelectorsExtension on _AddDepotBottomSheetState {
  Widget _phone(
    PhoneController controller,
    String hint, {
    String? label,
    IconData? icon,
    bool required = false,
    bool compact = false,
    String? error,
    required ValueChanged<String> onChanged,
  }) {
    final field = PhoneFormField(
      controller: controller,
      onChanged: (p) => onChanged(p.international),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: _fontSize(13),
        fontWeight: FontWeight.w500,
      ),
      countryButtonStyle: CountryButtonStyle(
        showFlag: true,
        showIsoCode: false,
        showDialCode: true,
        showDropdownIcon: true,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        textStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: _fontSize(12),
        ),
      ),
      validator: PhoneValidator.compose([
        PhoneValidator.required(context,
            errorText: 'add_depot.error.required'.tr),
        PhoneValidator.validMobile(context,
            errorText: 'add_depot.error.invalid_phone'.tr),
      ]),
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

  Widget _dropdown({
    required String? value,
    required List<SapOption> options,
    required ValueChanged<String?> onChanged,
    String? label,
    IconData? icon,
    bool required = false,
    bool compact = false,
    String? hint,
    String? error,
    bool isDisabled = false,
    bool showCode = false,
  }) {
    final resolved = [...options];
    final hasValue = value != null && value.isNotEmpty;
    if (hasValue && !resolved.any((o) => o.code == value)) {
      resolved.insert(
        0,
        SapOption(
            value, 'add_depot.unrecognised_code'.trParams({'code': value})),
      );
    }

    final dropdown = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isTablet ? 12 : context.rw(8),
        vertical: widget.isTablet ? 6 : context.rh(3),
      ),
      decoration: BoxDecoration(
        color: isDisabled
            ? context.appColors.border.withValues(alpha: 0.2)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: error != null
              ? Theme.of(context).colorScheme.error
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: hasValue ? value : null,
          onTap: () => FocusScope.of(context).unfocus(),
          isExpanded: true,
          isDense: true,
          hint: Text(
            hint ?? '',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: _fontSize(12),
            ),
          ),
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF64748B),
            size: _fontSize(18),
          ),
          items: isDisabled
              ? null
              : resolved
                  .map((o) => DropdownMenuItem<String>(
                        value: o.code,
                        child: Text(
                          showCode ? o.display : o.labelEn,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: _fontSize(12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
          onChanged: isDisabled ? null : onChanged,
        ),
      ),
    );

    if (label != null || icon != null) {
      return _inputCard(
        label: label,
        icon: icon,
        required: required,
        compact: compact,
        error: error,
        child: dropdown,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dropdown,
        if (error != null) _errorText('add_depot.$error'.tr),
      ],
    );
  }

  /// Two-option choices read better as a segmented control than a dropdown.
  Widget _segmented({
    required String? value,
    required List<SapOption> options,
    required ValueChanged<String> onChanged,
    bool compact = false,
  }) {
    return Row(
      children: [
        for (final o in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                onChanged(o.code);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 6 : context.rh(14),
                ),
                decoration: BoxDecoration(
                  color: value == o.code
                      ? Theme.of(context).colorScheme.secondary
                      : context.appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(compact ? 8 : 12),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Text(
                  o.labelEn,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: value == o.code
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: _fontSize(compact ? 11 : 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (o != options.last) SizedBox(width: compact ? 6 : 8),
        ],
      ],
    );
  }
}
