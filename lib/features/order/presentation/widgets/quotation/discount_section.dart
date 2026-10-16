import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class DiscountSection extends StatefulWidget {
  const DiscountSection({
    super.key,
    required this.selectedDiscount,
    required this.onDiscountSelected,
  });

  final int selectedDiscount;
  final ValueChanged<int> onDiscountSelected;

  @override
  State<DiscountSection> createState() => _DiscountSectionState();
}

class _DiscountSectionState extends State<DiscountSection> {
  final List<int> _presets = [0, 5, 10, 15, 20];
  final TextEditingController _customController = TextEditingController();
  bool _isCustomActive = false;

  @override
  void initState() {
    super.initState();
    if (!_presets.contains(widget.selectedDiscount)) {
      _isCustomActive = true;
      _customController.text = widget.selectedDiscount.toString();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presets.map((percent) {
              final isSelected =
                  !_isCustomActive && widget.selectedDiscount == percent;
              return ChoiceChip(
                label: Text('$percent%'),
                selected: isSelected,
                onSelected: (_) => _handlePresetTap(percent),
              );
            }),
            ChoiceChip(
              label: const Text('Custom'),
              selected: _isCustomActive,
              onSelected: (_) => _handleCustomTap(),
            ),
          ],
        ),
        if (_isCustomActive) ...[
          SizedBox(height: context.rh(12)),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: _onCustomValuesChanged,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: context.rsp(13),
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: 'orders.quotation_extra.enter_value'.tr,
                hintStyle: TextStyle(
                    fontSize: context.rsp(12), color: colors.textHint),
                suffixText: '%',
                suffixStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.brandNavy,
                ),
                filled: true,
                fillColor: colors.surfaceSoft,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.brandNavy, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handlePresetTap(int percent) {
    setState(() {
      _isCustomActive = false;
      _customController.clear();
    });
    widget.onDiscountSelected(percent);
  }

  void _handleCustomTap() {
    setState(() {
      _isCustomActive = true;
    });
  }

  void _onCustomValuesChanged(String value) {
    final parsed = int.tryParse(value) ?? 0;
    widget.onDiscountSelected(parsed);
  }
}
