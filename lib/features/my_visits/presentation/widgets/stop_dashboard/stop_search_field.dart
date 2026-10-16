import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Debounced search box for the Stop Dashboard. Emits [onChanged] 300 ms after
/// the last keystroke so filtering doesn't run on every character.
class StopSearchField extends StatefulWidget {
  const StopSearchField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<StopSearchField> createState() => _StopSearchFieldState();
}

class _StopSearchFieldState extends State<StopSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 300), () => widget.onChanged(value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: colors.textPrimary, fontSize: context.rsp(13)),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'my_visits.stop_dashboard.search_hint'.tr,
        hintStyle: TextStyle(color: colors.textHint, fontSize: context.rsp(13)),
        prefixIcon: Icon(Icons.search_rounded,
            size: context.rw(18), color: colors.textSecondary),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded,
                    size: context.rw(16), color: colors.textSecondary),
                onPressed: () {
                  _controller.clear();
                  _debounce?.cancel();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: colors.surfaceSoft,
        contentPadding: EdgeInsets.symmetric(
            vertical: context.rh(12), horizontal: context.rw(12)),
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
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
