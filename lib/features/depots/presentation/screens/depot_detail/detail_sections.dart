part of '../depot_detail_screen.dart';

/// A value as the details screen shows it: the server's text, or `null` when
/// it sent nothing — never a made-up placeholder.
String _orNull(String? value) {
  final text = value?.trim();
  return (text == null || text.isEmpty) ? 'depots.detail.null_value'.tr : text;
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: EdgeInsets.only(bottom: context.rh(12)),
      padding: EdgeInsets.fromLTRB(
          context.rr(14), context.rh(10), context.rr(14), context.rh(4)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
        // Flat on the saved document's page.
        boxShadow: _DocumentMode.of(context) ? null : colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(13),
              fontWeight: FontWeight.w800,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

_CompactTile _profileTile(IconData icon, String key, String? value,
        {bool last = false, VoidCallback? onTap}) =>
    _CompactTile(
      icon: icon,
      label: 'depots.detail.$key'.tr,
      value: _orNull(value),
      last: last,
      onTap: value == null ? null : onTap,
    );

/// `profile.fieldFacts`. A missing profile shows every value as null.
class _FieldFactsSection extends StatelessWidget {
  const _FieldFactsSection(this.profile);

  final DepotProfile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile ?? const DepotProfile();
    return _DetailSectionCard(
      title: 'depots.detail.section_field_facts'.tr,
      children: [
        _profileTile(Icons.send_rounded, 'telegram', p.telegram),
        _profileTile(
            Icons.storefront_outlined, 'outlet_status', p.outletStatus),
        _profileTile(Icons.home_outlined, 'house_number', p.houseNumber),
        _profileTile(Icons.location_on_outlined, 'address_line', p.addressLine,
            last: true),
      ],
    );
  }
}

/// `profile.suppliers`.
class _SuppliersSection extends StatelessWidget {
  const _SuppliersSection(this.profile);

  final DepotProfile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile ?? const DepotProfile();
    // A supplier with a code opens as a depot of its own.
    VoidCallback? open(String? code) =>
        code == null ? null : () => openDepotByCode(context, code);
    return _DetailSectionCard(
      title: 'depots.detail.section_suppliers'.tr,
      children: [
        _profileTile(
            Icons.looks_one_outlined, 'supplier_primary', p.primarySupplier,
            onTap: open(p.primarySupplierCode)),
        _profileTile(
            Icons.looks_two_outlined, 'supplier_secondary', p.secondarySupplier,
            onTap: open(p.secondarySupplierCode)),
        _profileTile(
            Icons.looks_3_outlined, 'supplier_tertiary', p.tertiarySupplier,
            last: true, onTap: open(p.tertiarySupplierCode)),
      ],
    );
  }
}

/// `profile.management`.
class _ManagementSection extends StatelessWidget {
  const _ManagementSection(this.profile);

  final DepotProfile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile ?? const DepotProfile();
    return _DetailSectionCard(
      title: 'depots.detail.section_management'.tr,
      children: [
        _profileTile(Icons.workspace_premium_outlined, 'tier', p.tier),
        _profileTile(Icons.hub_outlined, 'channel', p.channel),
        _profileTile(Icons.account_tree_outlined, 'sub_channel', p.subChannel),
        _profileTile(Icons.alt_route_rounded, 'action_tag', p.outletAction),
        _profileTile(Icons.key_outlined, 'key_account_id', p.keyAccountId),
        _profileTile(Icons.radar_rounded, 'coverage_type', p.coverageType),
        _profileTile(Icons.event_repeat_rounded, 'visit', p.visit),
        _profileTile(Icons.map_outlined, 'territory', p.territory, last: true),
      ],
    );
  }
}
