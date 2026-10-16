part of '../add_depot_bottom_sheet.dart';

extension SalesTermsStepExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // STEP 4 — Sales & Billing terms
  // ===========================================================================
  Widget _buildSalesTermsStep(Map<String, String> errors) {
    final draft = _bloc.state.draft;
    final refs = _bloc.state.references;
    draft.applyRepDefaults(_bloc.rep);
    final needsCredit =
        SapMasterData.paymentTermNeedsCreditApproval(draft.paymentTerm);
    // A required field inside the collapsed section must not fail silently.
    final showAdvanced = _showAdvancedTerms ||
        const {
          'paymentTerm',
          'salesOrg',
          'salesOffice',
          'salesGroup',
          'distributionChannel',
          'division',
          'deliveryPriority',
          'shippingCondition',
        }.any(errors.containsKey);

    final taxCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildIconBox(Icons.account_balance_wallet_outlined,
                  size: 24, iconSize: 13),
              const SizedBox(width: 6),
              Expanded(
                child: _cardLabel('add_depot.tax_class'.tr,
                    required: true, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _segmented(
            value: draft.taxClass,
            options: SapMasterData.taxClass,
            compact: true,
            onChanged: (v) => _edit((d) => d.taxClass = v),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _twoCol(
          _dropdown(
            label: 'add_depot.depot_group'.tr,
            icon: Icons.groups_2_outlined,
            required: true,
            compact: true,
            value: draft.depotGroup,
            options: refs.depotGroup,
            hint: 'add_depot.pick_one'.tr,
            error: errors['depotGroup'],
            onChanged: (v) => _edit((d) => d.depotGroup = v),
          ),
          _dropdown(
            label: 'add_depot.price_group'.tr,
            icon: Icons.sell_outlined,
            compact: true,
            value: draft.priceGroup,
            options: refs.priceGroup,
            hint: 'add_depot.pick_one'.tr,
            onChanged: (v) => _edit((d) {
              d.priceGroup = v;
              d.priceGroupOverridden = true;
            }),
          ),
        ),
        if (draft.priceGroup != null && !draft.priceGroupOverridden) ...[
          const SizedBox(height: 4),
          _infoChip(
              Icons.sell_outlined,
              'add_depot.price_group_auto'
                  .tr
                  .replaceAll('{code}', draft.priceGroup!)),
        ],
        if (needsCredit) ...[
          const SizedBox(height: 6),
          _creditNotice(),
        ],
        _gap(8),
        taxCard,
        if (draft.taxClass == '1') ...[
          _gap(8),
          _text(
            _vatTinCtrl,
            'add_depot.vat_tin_hint'.tr,
            label: 'add_depot.vat_tin'.tr,
            icon: Icons.receipt_long_outlined,
            required: true,
            compact: true,
            error: errors['vatTin'],
            onChanged: (v) => _edit((d) => d.vatTin = v),
          ),
        ],
        _gap(8),
        _moreToggle(
          expanded: showAdvanced,
          labelCollapsed: 'add_depot.adjust_defaults'.tr,
          onTap: () => setState(() => _showAdvancedTerms = !_showAdvancedTerms),
        ),
        if (showAdvanced) ...[
          _gap(8),
          _dropdown(
            label: 'add_depot.payment_term'.tr,
            icon: Icons.payments_outlined,
            required: true,
            compact: true,
            value: draft.paymentTerm,
            options: refs.paymentTerm,
            error: errors['paymentTerm'],
            onChanged: (v) => _edit((d) => d.paymentTerm = v),
          ),
          _gap(8),
          _twoCol(
            _dropdown(
              label: 'add_depot.sales_org'.tr,
              icon: Icons.corporate_fare_outlined,
              required: true,
              compact: true,
              value: draft.salesOrg,
              options: refs.salesOrg,
              hint: 'add_depot.pick_one'.tr,
              error: errors['salesOrg'],
              onChanged: (v) => _edit((d) => d.salesOrg = v),
            ),
            _dropdown(
              label: 'add_depot.sales_office'.tr,
              icon: Icons.apartment_outlined,
              required: true,
              compact: true,
              value: draft.salesOffice,
              options: refs.salesOffice,
              hint: 'add_depot.pick_one'.tr,
              error: errors['salesOffice'],
              onChanged: (v) => _edit((d) => d.salesOffice = v),
            ),
          ),
          _gap(8),
          _twoCol(
            _dropdown(
              label: 'add_depot.sales_group'.tr,
              icon: Icons.group_work_outlined,
              required: true,
              compact: true,
              value: draft.salesGroupCode,
              options: refs.salesGroup,
              hint: 'add_depot.pick_one'.tr,
              error: errors['salesGroup'],
              onChanged: (v) => _edit((d) => d.salesGroupCode = v),
            ),
            _dropdown(
              label: 'add_depot.distribution_channel'.tr,
              icon: Icons.alt_route_outlined,
              required: true,
              compact: true,
              value: draft.distributionChannel,
              options: refs.distributionChannel,
              error: errors['distributionChannel'],
              onChanged: (v) => _edit((d) => d.distributionChannel = v),
            ),
          ),
          _gap(8),
          _twoCol(
            _dropdown(
              label: 'add_depot.division'.tr,
              icon: Icons.pie_chart_outline,
              required: true,
              compact: true,
              value: draft.divisionCode,
              options: refs.division,
              error: errors['division'],
              onChanged: (v) => _edit((d) => d.divisionCode = v),
            ),
            _dropdown(
              label: 'add_depot.delivery_priority'.tr,
              icon: Icons.local_shipping_outlined,
              required: true,
              compact: true,
              value: draft.deliveryPriority,
              options: SapMasterData.deliveryPriority,
              error: errors['deliveryPriority'],
              onChanged: (v) => _edit((d) => d.deliveryPriority = v),
            ),
          ),
          _gap(8),
          _twoCol(
            _dropdown(
              label: 'add_depot.shipping_condition'.tr,
              icon: Icons.inventory_2_outlined,
              required: true,
              compact: true,
              value: draft.shippingCondition,
              options: refs.shippingCondition,
              error: errors['shippingCondition'],
              onChanged: (v) => _edit((d) => d.shippingCondition = v),
            ),
            _dropdown(
              label: 'add_depot.currency'.tr,
              icon: Icons.monetization_on_outlined,
              required: true,
              compact: true,
              value: draft.currency,
              options: SapMasterData.currency,
              onChanged: (v) => _edit((d) => d.currency = v!),
            ),
          ),
        ],
      ],
    );
  }
}
