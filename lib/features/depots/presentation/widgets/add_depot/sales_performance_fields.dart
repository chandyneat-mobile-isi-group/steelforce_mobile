part of '../add_depot_bottom_sheet.dart';

/// Text controllers for the sales & performance step, kept together so the
/// sheet holds one field for them rather than nine.
class _SurveyControllers {
  final steelSales = TextEditingController();
  final constructionSales = TextEditingController();
  final shareToDepots = TextEditingController();
  final shareToEndUsers = TextEditingController();
  final purchases = {
    for (final s in SteelSupplier.values) s: TextEditingController(),
  };

  /// Copies the draft into the fields. Q3 fills its other blank and a resumed
  /// draft fills them all, and neither is typed.
  void sync(DepotSalesSurvey survey) {
    _set(steelSales, survey.steelMonthlySales);
    _set(constructionSales, survey.constructionMonthlySales);
    _set(shareToDepots, survey.shareToDepots);
    _set(shareToEndUsers, survey.shareToEndUsers);
    for (final entry in purchases.entries) {
      _set(entry.value, survey.steelPurchases[entry.key] ?? '');
    }
  }

  /// Leaves the field alone while it already shows [value], so the cursor
  /// does not jump to the end on every keystroke.
  static void _set(TextEditingController c, String value) {
    if (c.text != value) c.text = value;
  }

  void dispose() {
    for (final c in [
      steelSales,
      constructionSales,
      shareToDepots,
      shareToEndUsers,
      ...purchases.values,
    ]) {
      c.dispose();
    }
  }
}

/// Question cards, choice chips and number fields for the survey step.
extension _SalesPerformanceFields on _AddDepotBottomSheetState {
  /// One survey question: a title that may wrap (Khmer questions are long),
  /// an optional note, the answer, and the error under it.
  Widget _surveyQuestion({
    required String title,
    String? note,
    bool required = false,
    String? error,
    required Widget child,
  }) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.isTablet ? 14 : context.rw(12)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null
              ? Theme.of(context).colorScheme.error
              : colors.border,
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
            text: title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: _fontSize(13),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          )),
          if (note != null) _hint(note),
          SizedBox(height: _spacing(8)),
          child,
          if (error != null) _errorText('add_depot.$error'.tr),
        ],
      ),
    );
  }

  /// Multi-choice answers as chips: each one a ≥48dp target and readable in
  /// both languages, where checkboxes in a row would wrap awkwardly in Khmer.
  Widget _surveyChoices<T>({
    required List<T> options,
    required Set<T> selected,
    required String Function(T) label,
    required void Function(T, bool) onChanged,
  }) =>
      Wrap(
        spacing: _spacing(8),
        runSpacing: _spacing(4),
        children: [
          for (final o in options)
            FilterChip(
              label: Text(label(o)),
              selected: selected.contains(o),
              showCheckmark: true,
              labelStyle: TextStyle(
                fontSize: _fontSize(12.5),
                fontWeight: FontWeight.w600,
              ),
              onSelected: (on) {
                FocusScope.of(context).unfocus();
                onChanged(o, on);
              },
            ),
        ],
      );

  /// A labelled number field: `$` for amounts, `%` for shares.
  Widget _surveyNumber({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    bool percent = false,
    bool emphasis = false,
    String? error,
  }) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: _spacing(6)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasis ? colors.textPrimary : colors.textSecondary,
                fontSize: _fontSize(12.5),
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: _spacing(8)),
          SizedBox(
            width: widget.isTablet ? 160 : context.rw(percent ? 92 : 132),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.numberWithOptions(decimal: !percent),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(percent ? r'\d' : r'[\d.]')),
                LengthLimitingTextInputFormatter(percent ? 3 : 12),
              ],
              onChanged: onChanged,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: _fontSize(13),
                fontWeight: FontWeight.w600,
              ),
              decoration:
                  _decoration(percent ? '0' : '0.00', error: error).copyWith(
                prefixText: percent ? null : r'$ ',
                suffixText: percent ? '%' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A computed line (Q2 total, Q3 total): looks like an answer, is not one.
  Widget _surveyTotal(String label, String value) => Padding(
        padding: EdgeInsets.only(top: _spacing(4)),
        child: Row(
          children: [
            Expanded(child: _cardLabel(label, fontSize: 12.5)),
            Text(
              value,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: _fontSize(13.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
