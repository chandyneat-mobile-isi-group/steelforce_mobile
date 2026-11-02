part of '../depot_detail_screen.dart';

/// `salesAreas`: one card per SAP sales area. Most outlets have exactly one.
/// [financial] picks which half of each area it shows — the Sales section's
/// org, channel and division, or the Financial section's payment and credit.
class _SalesAreasSection extends StatelessWidget {
  const _SalesAreasSection({required this.depot, required this.financial});
  final Depot depot;
  final bool financial;

  @override
  Widget build(BuildContext context) {
    final areas = depot.salesAreas ?? const <DepotSalesArea>[];
    if (areas.isEmpty) {
      return _EmptySectionCard(
        title: 'depots.detail.section_sales_areas'.tr,
        message: 'depots.detail.no_sales_area'.tr,
      );
    }
    return Column(
      children: [
        for (final area in areas)
          financial
              ? _FinancialCard(area: area, currency: depot.currency)
              : _SalesAreaCard(area: area),
      ],
    );
  }
}

/// Titled by the area, so a depot sold through two orgs reads as two cards.
/// By name only: a bare code like "0001" means nothing to a rep.
String _areaTitle(DepotSalesArea area) =>
    area.salesOrgName ?? 'depots.detail.section_sales_areas'.tr;

class _SalesAreaCard extends StatelessWidget {
  const _SalesAreaCard({required this.area});
  final DepotSalesArea area;

  @override
  Widget build(BuildContext context) {
    return _DetailSectionCard(
      title: _areaTitle(area),
      children: [
        _CompactTile(
            icon: Icons.apartment_rounded,
            label: 'depots.group.sales_org'.tr,
            // Names only, never the SAP code.
            value: _orNull(area.salesOrgName)),
        _CompactTile(
            icon: Icons.hub_outlined,
            label: 'depots.detail.distribution_channel'.tr,
            value: _orNull(area.channelName)),
        _CompactTile(
            icon: Icons.category_outlined,
            label: 'depots.detail.division_label'.tr,
            // The name; the code only when it cannot be named.
            value: _orNull(area.divisionName ?? area.division),
            last: true),
      ],
    );
  }
}

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.area, required this.currency});
  final DepotSalesArea area;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final limitDate = area.creditLimitDate;
    return _DetailSectionCard(
      title: _areaTitle(area),
      children: [
        _CompactTile(
            icon: Icons.calendar_month_outlined,
            label: 'depots.detail.payment_term'.tr,
            value: _orNull(
                _codeName(area.paymentTermsCode, area.paymentTermsName))),
        _CompactTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'depots.credit_limit'.tr,
            value: _orNull(_money(area.creditLimit))),
        _CompactTile(
            icon: Icons.event_available_outlined,
            label: 'depots.detail.credit_limit_date'.tr,
            value: _orNull(limitDate == null
                ? null
                : DateFormat('yyyy-MM-dd').format(limitDate))),
        _CompactTile(
          icon: Icons.event_repeat_rounded,
          label: 'depots.detail.credit_term'.tr,
          value: _orNull(area.creditTermDays == null
              ? null
              : 'depots.detail.credit_term_days'
                  .trParams({'n': '${area.creditTermDays}'})),
          last: true,
        ),
      ],
    );
  }

  /// Never drops the currency: an amount alone could be read as riel.
  String? _money(double? amount) => amount == null
      ? null
      : NumberFormat.simpleCurrency(name: currency).format(amount);
}

/// `Contractor (50)`; whichever half is missing is left out.
String? _codeName(String? code, String? name) => switch ((code, name)) {
      (null, null) => null,
      (final c?, null) => c,
      (null, final n?) => n,
      (final c?, final n?) => '$n ($c)',
    };

/// A section the server sent nothing for: its title and why it is empty.
class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _DetailSectionCard(
      title: title,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: context.rh(10)),
          child: Text(
            message,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: context.rsp(12.5),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
