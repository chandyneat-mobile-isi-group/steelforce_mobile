import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/category.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Horizontal, single-select category rail with icon tiles, an animated
/// active state, a ripple, and automatic scroll-to-reveal of
/// the selected tile (e.g. when a persisted category is restored off-screen).
class FilterCategorySelector extends StatefulWidget {
  const FilterCategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelect;

  @override
  State<FilterCategorySelector> createState() => _FilterCategorySelectorState();
}

class _FilterCategorySelectorState extends State<FilterCategorySelector> {
  static const _allKey = '__all__';
  final _controller = ScrollController();
  final _tileKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(FilterCategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId) {
      _revealSelected();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealSelected() {
    final activeKey = widget.selectedCategoryId ?? _allKey;
    final key = _tileKeys[activeKey];
    if (key == null || key.currentContext == null) return;

    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  GlobalKey _keyFor(String id) => _tileKeys.putIfAbsent(id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.rh(78),
      child: ListView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Tile(
            key: _keyFor(_allKey),
            label: 'All',
            icon: Icons.grid_view_rounded,
            selected: widget.selectedCategoryId == null,
            onTap: () => widget.onSelect(null),
          ),
          ...widget.categories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _Tile(
                key: _keyFor(cat.id),
                label: context.localized(cat.name),
                icon: _getIconData(cat.icon ?? cat.code),
                selected: widget.selectedCategoryId == cat.id,
                onTap: () => widget.onSelect(cat.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getIconData(String code) {
    return switch (code.toLowerCase()) {
      'pipe' => Icons.radio_button_unchecked_rounded,
      'truss' => Icons.architecture_rounded,
      'deck' => Icons.layers_rounded,
      _ => Icons.category_rounded,
    };
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? activeColor : context.appColors.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: context.rr(22),
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            SizedBox(height: context.rh(6)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.rsp(10.5),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
