part of '../add_depot_bottom_sheet.dart';

extension _SalesPerformanceStep on _AddDepotBottomSheetState {
  // ===========================================================================
  // STEP 5 — Sales & performance (field survey Q1–Q4)
  // ===========================================================================
  Widget _buildSalesPerformanceStep(Map<String, String> errors) {
    final survey = _bloc.state.draft.salesSurvey;
    final c = _surveyCtrls;
    final money = NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 2);

    void edit(void Function(DepotSalesSurvey s) mutate) =>
        _edit((d) => mutate(d.salesSurvey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Q1 — what the depot sells.
        _surveyQuestion(
          title: 'add_depot.survey.q1'.tr,
          required: true,
          error: errors['surveyProductLines'],
          child: _surveyChoices<SurveyProductLine>(
            options: SurveyProductLine.values,
            selected: survey.productLines,
            label: (l) => 'add_depot.survey.line.${l.name}'.tr,
            onChanged: (l, on) => edit((s) => s.setProductLine(l, on)),
          ),
        ),
        // Q1.1 — only for a depot that sells steel.
        if (survey.sellsSteel) ...[
          _gap(8),
          _surveyQuestion(
            title: 'add_depot.survey.q1_1'.tr,
            required: true,
            error: errors['surveySteelTypes'],
            child: _surveyChoices<SurveySteelType>(
              options: SurveySteelType.values,
              selected: survey.steelTypes,
              label: (t) => 'add_depot.survey.steel_type.${t.name}'.tr,
              onChanged: (t, on) => edit(
                  (s) => on ? s.steelTypes.add(t) : s.steelTypes.remove(t)),
            ),
          ),
        ],
        // Q2 — monthly sales per line the depot sells.
        if (survey.productLines.isNotEmpty) ...[
          _gap(8),
          _surveyQuestion(
            title: 'add_depot.survey.q2'.tr,
            note:
                survey.sellsConstruction ? 'add_depot.survey.q2_note'.tr : null,
            required: true,
            child: Column(
              children: [
                if (survey.sellsSteel)
                  _surveyNumber(
                    controller: c.steelSales,
                    label: 'add_depot.survey.line.steel'.tr,
                    error: errors['surveySteelSales'],
                    onChanged: (v) => edit((s) => s.steelMonthlySales = v),
                  ),
                if (survey.sellsConstruction)
                  _surveyNumber(
                    controller: c.constructionSales,
                    label: 'add_depot.survey.line.construction'.tr,
                    error: errors['surveyConstructionSales'],
                    onChanged: (v) =>
                        edit((s) => s.constructionMonthlySales = v),
                  ),
                _surveyTotal('add_depot.survey.total'.tr,
                    money.format(survey.totalMonthlySales)),
                ..._fieldErrors(errors, const [
                  'surveySteelSales',
                  'surveyConstructionSales',
                ]),
              ],
            ),
          ),
        ],
        if (survey.sellsSteel) ...[
          // Q3 — who buys the steel, by value. Typing one share fills the
          // other, so the pair always makes 100.
          _gap(8),
          _surveyQuestion(
            title: 'add_depot.survey.q3'.tr,
            note: 'add_depot.survey.q3_note'.tr,
            required: true,
            error: errors['surveyShare'],
            child: Column(
              children: [
                _surveyNumber(
                  controller: c.shareToDepots,
                  label: 'add_depot.survey.share_depots'.tr,
                  percent: true,
                  onChanged: (v) => edit((s) => s.setShareToDepots(v)),
                ),
                _surveyNumber(
                  controller: c.shareToEndUsers,
                  label: 'add_depot.survey.share_end_users'.tr,
                  percent: true,
                  onChanged: (v) => edit((s) => s.setShareToEndUsers(v)),
                ),
                _surveyTotal('add_depot.survey.total'.tr, '100%'),
              ],
            ),
          ),
          // Q4 — steel bought per supplier. Optional: a rep is often not told.
          _gap(8),
          _surveyQuestion(
            title: 'add_depot.survey.q4'.tr,
            note: 'add_depot.survey.optional'.tr,
            child: Column(
              children: [
                for (final supplier in SteelSupplier.values)
                  _surveyNumber(
                    controller: c.purchases[supplier]!,
                    label: 'add_depot.survey.supplier.${supplier.name}'.tr,
                    error: errors['surveyPurchase_${supplier.name}'],
                    onChanged: (v) =>
                        edit((s) => s.steelPurchases[supplier] = v),
                  ),
                ..._fieldErrors(errors, [
                  for (final s in SteelSupplier.values)
                    'surveyPurchase_${s.name}'
                ]),
              ],
            ),
          ),
        ],
        _gap(8),
        _infoChip(
            Icons.lock_outline_rounded, 'add_depot.survey.saved_on_device'.tr),
      ],
    );
  }

  /// The first error among [keys], under a group of fields that share a card.
  List<Widget> _fieldErrors(Map<String, String> errors, List<String> keys) {
    final key = keys.where(errors.containsKey).firstOrNull;
    return key == null ? const [] : [_errorText('add_depot.${errors[key]}'.tr)];
  }
}
