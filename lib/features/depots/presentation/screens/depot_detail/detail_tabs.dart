part of '../depot_detail_screen.dart';

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.depot,
    required this.onPhoneTap,
    required this.onLocationTap,
  });

  final Depot depot;
  final Function(String) onPhoneTap;
  final Function(double, double) onLocationTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final address = [depot.address, depot.district, depot.province]
        .where((part) => part.trim().isNotEmpty)
        .join(', ');

    final outletId = depot.sapDepotId?.isNotEmpty == true
        ? depot.sapDepotId!
        : (depot.depotCode.isNotEmpty ? depot.depotCode : _fallbackOutletId);
    final outletType = (depot.depotGroup?.isNotEmpty ?? false)
        ? depot.depotGroup!
        : _fallbackOutletType;
    final ownerName =
        depot.ownerName.isNotEmpty ? depot.ownerName : _fallbackOwnerName;
    final phoneNum = depot.phone.isNotEmpty ? depot.phone : _fallbackPhone;
    final telegram = (depot.whatsapp?.isNotEmpty ?? false)
        ? depot.whatsapp!
        : _fallbackTelegram;
    final addressLine = address.isNotEmpty ? address : _fallbackAddress;
    final latitude = depot.hasCoordinates ? depot.latitude : _fallbackLatitude;
    final longitude =
        depot.hasCoordinates ? depot.longitude : _fallbackLongitude;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(12),
        context.pagePadding,
        context.rh(20),
      ),
      children: [
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
                  label: 'depots.detail.sap_id'.tr,
                  value: outletId),
              _CompactTile(
                  icon: Icons.store_outlined,
                  label: 'depots.detail.depot_type'.tr,
                  value: outletType),
              _CompactTile(
                  icon: Icons.alt_route_rounded,
                  label: 'depots.detail.action_tag'.tr,
                  value: _fallbackOutletAction),
              _CompactTile(
                  icon: Icons.person_outline_rounded,
                  label: 'depots.detail.contact_person'.tr,
                  value: ownerName),
              _CompactTile(
                icon: Icons.call_outlined,
                label: 'depots.detail.phone_number'.tr,
                value: phoneNum,
                onTap: () => onPhoneTap(phoneNum),
              ),
              _CompactTile(
                  icon: Icons.send_rounded,
                  label: 'depots.detail.telegram'.tr,
                  value: telegram),
              _CompactTile(
                  icon: Icons.location_on_outlined,
                  label: 'depots.detail.address'.tr,
                  value: addressLine),
              _CompactTile(
                icon: Icons.my_location_rounded,
                label: 'depots.detail.coordinates'.tr,
                value:
                    '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                last: true,
                onTap: () => onLocationTap(latitude, longitude),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SalesTab extends StatelessWidget {
  const _SalesTab({required this.depot});
  final Depot depot;

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
              _CompactTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Payment Status',
                  value: 'Good Standing'),
              _CompactTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Credit Limit',
                  value: '\$50,000'),
              _CompactTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Payment Term',
                  value: '30 Days Net'),
              _CompactTile(
                  icon: Icons.trending_up_rounded,
                  label: 'Avg Rev per Order',
                  value: '\$12,500'),
              _CompactTile(
                  icon: Icons.history_toggle_off_rounded,
                  label: 'Latest Order',
                  value: '12 Aug 2026',
                  last: true),
            ],
          ),
        ),
        SizedBox(height: context.rh(12)),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderHistoryScreen(
                  outletName: context.localized(depot.displayName),
                ),
              ),
            );
          },
          icon: Icon(Icons.receipt_long_rounded, size: context.rr(18)),
          label: const Text('View Complete Order History'),
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
  const _PromosTab({required this.depot});
  final Depot depot;

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
                    'Active Promotions',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _PillBadge(
                      label: '25 Available',
                      color: Colors.amber.shade100,
                      textColor: Colors.amber.shade900),
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
                      textColor: Colors.blue.shade900),
                  _PillBadge(
                      label: 'OFF-INVOICE (0)',
                      color: Colors.grey.shade200,
                      textColor: Colors.grey.shade700),
                  _PillBadge(
                      label: 'CONTRACT (5)',
                      color: Colors.teal.shade100,
                      textColor: Colors.teal.shade900),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(12)),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PromotionsScreen(
                  depotId: depot.id,
                  outletName: context.localized(depot.displayName),
                ),
              ),
            );
          },
          icon: Icon(Icons.local_offer_outlined, size: context.rr(18)),
          label: const Text('Browse All Promotions'),
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
