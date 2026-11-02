import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class DepotSearchBar extends StatefulWidget {
  const DepotSearchBar({
    super.key,
    required this.query,
    required this.onSearchChanged,
    this.trailing,
  });

  final String query;
  final ValueChanged<String> onSearchChanged;

  /// Beside the field — the Advanced Filters button. Registering a depot
  /// moved to the screen's floating button.
  final Widget? trailing;

  @override
  State<DepotSearchBar> createState() => _DepotSearchBarState();
}

class _DepotSearchBarState extends State<DepotSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query); //

    // Add FocusNode to animate the search bar when the user taps into it
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DepotSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && _controller.text != widget.query) {
      //
      _controller.value = TextEditingValue(
        text: widget.query,
        selection:
            TextSelection.collapsed(offset: widget.query.length), //[cite: 24]
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose(); //[cite: 24]
    super.dispose(); //[cite: 24]
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors; //[cite: 24]
    final scheme = Theme.of(context).colorScheme;
    final isFocused = _focusNode.hasFocus;

    return Row(
      children: [
        Expanded(
          //[cite: 24]
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: context.rh(44), //[cite: 24]
            padding: const EdgeInsets.symmetric(horizontal: 12), //[cite: 24]
            decoration: BoxDecoration(
              color:
                  isFocused ? colors.card : colors.card.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14), //[cite: 24]
              // Premium style: primary color border when focused, default otherwise
              border: Border.all(
                color: isFocused ? scheme.primary : colors.border,
                width: isFocused ? 1.5 : 1.0,
              ),
              // Premium style: subtle glowing drop shadow when focused
              boxShadow: [
                BoxShadow(
                  color: isFocused
                      ? scheme.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: isFocused ? 12 : 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.search_rounded, //[cite: 24]
                    key: ValueKey(isFocused),
                    color: isFocused ? scheme.primary : colors.textSecondary,
                    size: context.rr(20), //[cite: 24]
                  ),
                ),
                SizedBox(width: context.rw(8)), //[cite: 24]
                Expanded(
                  child: TextField(
                    controller: _controller, //[cite: 24]
                    focusNode: _focusNode,
                    onChanged: widget.onSearchChanged, //[cite: 24]
                    style: TextStyle(
                      color: colors.textPrimary, //[cite: 24]
                      fontSize: context.rsp(13.5), //[cite: 24]
                    ),
                    decoration: InputDecoration(
                      isDense: true, //[cite: 24]
                      border: InputBorder.none, //[cite: 24]
                      hintText: 'depots.search_hint'.tr, //[cite: 24]
                      hintStyle: TextStyle(
                        color: colors.textSecondary, //[cite: 24]
                        fontSize: context.rsp(13.5), //[cite: 24]
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.trailing case final trailing?) ...[
          SizedBox(width: context.rw(10)),
          trailing,
        ],
      ],
    );
  }
}
