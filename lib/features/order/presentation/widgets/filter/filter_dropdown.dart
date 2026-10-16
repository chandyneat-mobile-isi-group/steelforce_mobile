import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// A dropdown-style filter field that opens a searchable bottom-sheet picker.
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
    this.hint,
    this.enabled = true,
    this.loading = false,
    this.searchable = true,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final IconData? icon;
  final String? hint;
  final bool enabled;
  final bool loading;
  final bool searchable;

  bool get _isDisabled => !enabled || loading;

  Future<void> _open(BuildContext context) async {
    if (_isDisabled) return;
    final result = await showModalBottomSheet<_PickResult>(
      constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickerSheet(
        label: label,
        currentValue: value,
        options: options,
        searchable: searchable,
      ),
    );

    if (result != null) {
      onChanged(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.rsp(13),
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: context.rh(6)),
        InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: context.rh(48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _isDisabled
                  ? theme.disabledColor.withValues(alpha: 0.05)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasValue
                    ? theme.colorScheme.primary
                    : context.appColors.border,
                width: hasValue ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: context.rr(20),
                    color: hasValue
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  SizedBox(width: context.rw(10)),
                ],
                Expanded(
                  child: Text(
                    value ??
                        hint ??
                        'orders.filter.select'.trParams({'label': label}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.rsp(14),
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                      color: hasValue
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hasValue && enabled)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.close_rounded,
                        size: context.rr(18),
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  )
                else
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: context.rr(20),
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PickResult {
  final String? value;
  const _PickResult(this.value);
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.label,
    required this.currentValue,
    required this.options,
    required this.searchable,
  });

  final String label;
  final String? currentValue;
  final List<String> options;
  final bool searchable;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.options
        .where((opt) => opt.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'orders.filter.select'.trParams({'label': widget.label}),
                      style: TextStyle(
                          fontSize: context.rsp(16),
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (widget.searchable)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'common.search'.tr,
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: filtered.isEmpty
                  ? const _EmptyOptions()
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final option = filtered[idx];
                        final isSelected = option == widget.currentValue;
                        return ListTile(
                          title: Text(
                            option,
                            style: TextStyle(
                              fontSize: context.rsp(14),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: theme.colorScheme.primary,
                                  size: context.rr(20))
                              : null,
                          onTap: () =>
                              Navigator.of(context).pop(_PickResult(option)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOptions extends StatelessWidget {
  const _EmptyOptions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: context.rr(36),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            SizedBox(height: context.rh(8)),
            Text(
              'orders.filter.no_matching_options'.tr,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: context.rsp(13)),
            ),
          ],
        ),
      ),
    );
  }
}
