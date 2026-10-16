import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/theme/app_colors.dart';

class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    this.length = 6,
    this.autofocus = true,
    this.onCompleted,
  });

  final int length;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpField> createState() => OtpFieldState();
}

class OtpFieldState extends State<OtpField> {
  late final List<TextEditingController> _controllers =
      List.generate(widget.length, (_) => TextEditingController());
  late final List<FocusNode> _nodes =
      List.generate(widget.length, (_) => FocusNode());

  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get value => _controllers.map((c) => c.text).join();

  bool validate() {
    final complete = value.length == widget.length;
    setState(() => _error = complete ? null : 'auth.otp_incomplete'.tr);
    return complete;
  }

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _error = null);
    if (_nodes.isNotEmpty) _nodes.first.requestFocus();
  }

  void _handleChange(int index, String text) {
    if (text.length > 1) {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < digits.length && index + i < widget.length; i++) {
        _controllers[index + i].text = digits[i];
      }
      final next = (index + digits.length).clamp(0, widget.length - 1);
      _nodes[next].requestFocus();
    } else if (text.isNotEmpty) {
      if (index + 1 < widget.length) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
      }
    }

    if (_error != null) setState(() => _error = null);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  void _handleBackspace(int index) {
    if (index > 0) {
      _nodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) SizedBox(width: context.rw(8)),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.rw(56)),
                  child: _box(i),
                ),
              ),
            ],
          ],
        ),
        if (_error != null) ...[
          SizedBox(height: context.rh(8)),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: context.rsp(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _box(int index) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(AppColors.radius)),
          borderSide: BorderSide(color: c, width: w),
        );

    final hasError = _error != null;

    return SizedBox(
      height: context.rh(56),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty) {
            _handleBackspace(index);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _nodes[index],
          autofocus: widget.autofocus && index == 0,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: index == widget.length - 1
              ? TextInputAction.done
              : TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: context.rsp(20),
            fontWeight: FontWeight.w700,
          ),
          cursorColor: scheme.secondary,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.surfaceStrong,
            contentPadding: EdgeInsets.symmetric(vertical: context.rh(14)),
            enabledBorder: border(hasError ? scheme.error : colors.border),
            focusedBorder:
                border(hasError ? scheme.error : scheme.secondary, 1.6),
          ),
          onChanged: (text) => _handleChange(index, text),
        ),
      ),
    );
  }
}
