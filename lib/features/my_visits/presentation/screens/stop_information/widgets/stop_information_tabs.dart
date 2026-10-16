part of '../stop_information_screen.dart';

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.stop,
    required this.onPhoneTap,
    required this.onLocationTap,
  });

  final RouteStop stop;
  final Function(String) onPhoneTap;
  final Function(double, double) onLocationTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final c = stop.depot;

    // The route sync gives a name, a pin and a geofence. Everything below
    // comes from `GET /mobile/depots/{id}/stop-information`, fetched when this
    // stop was opened — and falls back to the sync's copy, never to a
    // hardcoded example.
    final outlet = _stopInformationOf(context)?.outlet;

    final phoneNum = _orDash(outlet?.phone.isNotEmpty == true
        ? outlet!.phone
        : (c.phone.isEmpty ? null : c.phone));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(12),
        context.pagePadding,
        context.rh(20),
      ),
      children: [
        const _DetailsStatusBanner(),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: context.rr(14), vertical: context.rh(6)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(16)),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadow,
          ),
          child: Column(
            children: [
              _CompactTile(
                  icon: Icons.tag_rounded,
                  label: 'my_visits.stop_info.sap_id'.tr,
                  value: _orDash(
                      outlet?.code.isNotEmpty == true ? outlet!.code : c.code)),
              // Never the route sync's `territoryType`: it collapses
              // Distributor and Wholesaler both onto `industrial`, so the
              // real value cannot be recovered from it.
              _CompactTile(
                  icon: Icons.store_outlined,
                  label: 'my_visits.stop_info.outlet_type'.tr,
                  value: _orDash(outlet?.outletType)),
              // OBD-2: no assignment process for Attack / Defend / Maintain.
              _CompactTile(
                  icon: Icons.alt_route_rounded,
                  label: 'my_visits.stop_info.outlet_action'.tr,
                  value: 'Attack',
                  isExample: true),
              _CompactTile(
                icon: Icons.person_outline_rounded,
                label: 'my_visits.stop_info.contact_person'.tr,
                // Null means nobody was recorded — said plainly, never filled
                // with a name the rep might ask for at the counter.
                value: outlet?.contact ??
                    (c.contact.isNotEmpty
                        ? c.contact
                        : 'my_visits.stop_info.not_recorded'.tr),
              ),
              _CompactTile(
                icon: Icons.call_outlined,
                label: 'my_visits.stop_info.phone_number'.tr,
                value: phoneNum,
                onTap:
                    phoneNum == _kNoValue ? null : () => onPhoneTap(phoneNum),
              ),
              _CompactTile(
                  icon: Icons.send_rounded,
                  label: 'my_visits.stop_info.telegram'.tr,
                  // Stored without the `@`; added only for display.
                  value: _orDash(outlet?.telegramHandle)),
              _CompactTile(
                  icon: Icons.location_on_outlined,
                  label: 'my_visits.stop_info.address'.tr,
                  value: _orDash(outlet?.address.isNotEmpty == true
                      ? outlet!.address
                      : c.address)),
              // `0.0000, 0.0000` is not a coordinate, it is the absence of
              // one — and rendering it as a tappable link sent the rep's map
              // app to the Gulf of Guinea. Said plainly and left inert
              // instead, exactly as the contact row does.
              _CompactTile(
                icon: Icons.my_location_rounded,
                label: 'my_visits.stop_info.coordinates'.tr,
                value: c.hasCoordinates
                    ? '${c.latitude.toStringAsFixed(4)}, ${c.longitude.toStringAsFixed(4)}'
                    : 'my_visits.stop_info.not_recorded'.tr,
                last: true,
                onTap: c.hasCoordinates
                    ? () => onLocationTap(c.latitude, c.longitude)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SalesTab extends StatelessWidget {
  const _SalesTab({required this.stop});
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final credit = _stopInformationOf(context)?.credit;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(12),
        context.pagePadding,
        context.rh(20),
      ),
      children: [
        const _DetailsStatusBanner(),
        Container(
          padding: EdgeInsets.all(context.rr(14)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(16)),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OBD-3: no invoice, due date or receivable exists anywhere, so
              // "Overdue" is uncomputable — this figure cannot be real yet.
              _CompactTile(
                  icon: Icons.verified_user_outlined,
                  label: 'my_visits.stop_info.payment_status'.tr,
                  value: 'Good Standing',
                  isExample: true),
              _CompactTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'my_visits.stop_info.credit_limit'.tr,
                  // Zero is a real answer here — cash-only trade — so it is
                  // rendered as \$0.00 rather than re-defaulted to a dash.
                  value: _money(credit?.creditLimit)),
              _CompactTile(
                  icon: Icons.account_balance_outlined,
                  label: 'my_visits.stop_info.available_credit'.tr,
                  // Server-computed. Never limit − balance on the client: a
                  // client that subtracts can disagree with the server about
                  // an outlet's headroom.
                  value: _money(credit?.availableCredit)),
              _CompactTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'my_visits.stop_info.payment_term'.tr,
                  // Label, else the raw code — the server will not echo the
                  // code back as a label, so null means genuinely unresolved.
                  value: _orDash(credit?.paymentTermDisplay)),
              // OBD-6: undecided which quotation statuses count as a won order.
              _CompactTile(
                  icon: Icons.trending_up_rounded,
                  label: 'my_visits.stop_info.avg_revenue'.tr,
                  value: '\$12,500',
                  isExample: true),
              _CompactTile(
                  icon: Icons.history_toggle_off_rounded,
                  label: 'my_visits.stop_info.latest_order'.tr,
                  value: '12 Aug 2026',
                  isExample: true,
                  last: true),
            ],
          ),
        ),
        SizedBox(height: context.rh(12)),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              AppPageRoute<void>.sharedAxisVertical(
                builder: (_) => OrderHistoryScreen(
                  outletName: context.localized(stop.depot.displayName),
                ),
              ),
            );
          },
          icon: Icon(Icons.receipt_long_rounded, size: context.rr(18)),
          label: Text('my_visits.stop_info.order_history'.tr),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(vertical: context.rh(12)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rr(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromosTab extends StatelessWidget {
  const _PromosTab({required this.stop});
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(12),
        context.pagePadding,
        context.rh(20),
      ),
      children: [
        Container(
          padding: EdgeInsets.all(context.rr(16)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(context.rr(16)),
            border: Border.all(color: colors.border),
            boxShadow: colors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'my_visits.stop_info.active_promotions'.tr,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // Marked as examples for the same reason as the five
                  // figures on the other two tabs: these four counts are
                  // constants, not a promotion query. An unmarked "25
                  // Available" is a number a rep will quote at the counter,
                  // and it is the same 25 for every outlet in the country.
                  // The real counts live behind
                  // `GET /mobile/depots/{id}/promotions`, which this tab does
                  // not call — `PromotionsScreen` below does.
                  _PillBadge(
                      label: '25 Available',
                      color: Colors.amber.shade100,
                      textColor: Colors.amber.shade900,
                      isExample: true),
                ],
              ),
              SizedBox(height: context.rh(14)),
              Wrap(
                spacing: context.rw(8),
                runSpacing: context.rh(8),
                children: [
                  _PillBadge(
                      label: 'ON-INVOICE (20)',
                      color: Colors.blue.shade100,
                      textColor: Colors.blue.shade900,
                      isExample: true),
                  _PillBadge(
                      label: 'OFF-INVOICE (0)',
                      color: Colors.grey.shade200,
                      textColor: Colors.grey.shade700,
                      isExample: true),
                  _PillBadge(
                      label: 'CONTRACT (5)',
                      color: Colors.teal.shade100,
                      textColor: Colors.teal.shade900,
                      isExample: true),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(12)),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              AppPageRoute<void>.sharedAxisVertical(
                builder: (_) => PromotionsScreen(
                  depotId: stop.depot.id,
                  outletName: context.localized(stop.depot.displayName),
                ),
              ),
            );
          },
          icon: Icon(Icons.local_offer_outlined, size: context.rr(18)),
          label: Text('my_visits.stop_info.browse_promotions'.tr),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: context.rh(12)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rr(12)),
            ),
          ),
        ),
      ],
    );
  }
}
