import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';

/// The postal code, derived where possible and typeable where not.
///
/// ## Why it is not simply read-only
///
/// The spec asks for a locked field, and for 1,547 of 1,646 communes that is
/// exactly what this renders. The other 99 have no code in the postal source,
/// and a permanently locked field would leave a rep with a required, empty,
/// uneditable input and no way forward. So the lock follows the data: derived →
/// locked with a lock icon; underived → an ordinary six-digit input with a hint
/// explaining why they are being asked.
class PostalCodeField extends StatefulWidget {
  const PostalCodeField({
    super.key,
    required this.value,
    required this.isDerived,
    required this.isEditable,
    required this.onChanged,
    this.errorText,
    this.isRequired = true,
    this.compact = false,
    this.isLocked = false,
  });

  /// The effective code — the commune's, or what the rep typed.
  final String? value;

  /// True when [value] came from the gazetteer.
  final bool isDerived;

  /// True when a commune is selected but carries no code.
  final bool isEditable;

  /// True when locked so user cannot edit it.
  final bool isLocked;

  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool isRequired;
  final bool compact;

  @override
  State<PostalCodeField> createState() => _PostalCodeFieldState();
}

class _PostalCodeFieldState extends State<PostalCodeField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(PostalCodeField old) {
    super.didUpdateWidget(old);
    // Only push a derived or locked value into the controller. Overwriting on every
    // rebuild would fight the rep's cursor while they type the manual case,
    // and the bloc already holds what they typed.
    final incoming = widget.value ?? '';
    if ((widget.isDerived || widget.isLocked) && _controller.text != incoming) {
      _controller.text = incoming;
    }
    // A commune change that clears the code has to clear the box too, or the
    // previous commune's code stays visible under the new selection (§8).
    if (!widget.isDerived &&
        incoming.isEmpty &&
        old.value != null &&
        old.value!.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null;
    final isFieldLocked = widget.isLocked || !widget.isEditable;
    final isFieldDerived = widget.isDerived || widget.isLocked;

    final card = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 12,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? theme.colorScheme.error : const Color(0xFFE2E8F0),
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
      child: widget.compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.mail_outline,
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          text: 'geo.postal_code'.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          children: [
                            if (widget.isRequired)
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: _controller,
                  readOnly: isFieldLocked,
                  enabled:
                      isFieldLocked || widget.isDerived || widget.isEditable,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: widget.onChanged,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: isFieldDerived
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFF8FAFC),
                    hintText: !isFieldLocked
                        ? 'geo.postal_hint'.tr
                        : 'geo.postal_code'.tr,
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        isFieldDerived
                            ? Icons.lock_outline
                            : Icons.qr_code_scanner_rounded,
                        size: 16,
                        color: isFieldDerived
                            ? const Color(0xFF64748B)
                            : const Color(0xFF3B82F6),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mail_outline,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          text: 'geo.postal_code'.tr,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          children: [
                            if (widget.isRequired)
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: _controller,
                        readOnly: isFieldLocked,
                        enabled: isFieldLocked ||
                            widget.isDerived ||
                            widget.isEditable,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: widget.onChanged,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: isFieldDerived
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFF8FAFC),
                          hintText: !isFieldLocked
                              ? 'geo.postal_hint'.tr
                              : 'geo.postal_code'.tr,
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              isFieldDerived
                                  ? Icons.lock_outline
                                  : Icons.qr_code_scanner_rounded,
                              size: 18,
                              color: isFieldDerived
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF3B82F6),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: theme.colorScheme.primary),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );

    if (hasError || (widget.isEditable && !widget.isDerived)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          card,
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                widget.errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (widget.isEditable)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'geo.postal_manual_notice'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      );
    }
    return card;
  }
}
