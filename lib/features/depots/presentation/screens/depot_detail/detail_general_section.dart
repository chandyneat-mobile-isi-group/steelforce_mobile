part of '../depot_detail_screen.dart';

/// General Information: names, address, type, status, phone, place.
class _DepotFactsSection extends StatelessWidget {
  const _DepotFactsSection({
    required this.depot,
    required this.onPhoneTap,
    required this.onLocationTap,
  });

  final Depot depot;
  final Function(String) onPhoneTap;
  final Function(double, double) onLocationTap;

  @override
  Widget build(BuildContext context) {
    final phone = depot.contactPhone;
    return _DetailSectionCard(
      title: 'depots.detail.section_general'.tr,
      children: [
        _CompactTile(
            icon: Icons.storefront_outlined,
            label: 'depots.detail.name_en'.tr,
            value: _orNull(depot.enName ?? depot.shopName)),
        _CompactTile(
            icon: Icons.translate_rounded,
            label: 'depots.detail.name_kh'.tr,
            value: _orNull(depot.khName)),
        // As the server sends it — the full "village, district, province,
        // code" where it has one — so it wraps instead of being cut short.
        _CompactTile(
            icon: Icons.location_on_outlined,
            label: 'depots.detail.address'.tr,
            value: _orNull(depot.address.trim()),
            valueMaxLines: 3),
        _CompactTile(
            icon: Icons.store_outlined,
            label: 'depots.detail.depot_type'.tr,
            value: _orNull(_typeLabel(depot.depotType))),
        _CompactTile(
            icon: Icons.verified_outlined,
            label: 'depots.detail.status'.tr,
            value: depot.status.apiValue),
        _CompactTile(
          icon: Icons.call_outlined,
          label: 'depots.detail.phone_number'.tr,
          value: _orNull(phone),
          onTap: phone.isEmpty ? null : () => onPhoneTap(phone),
        ),
        _CompactTile(
          icon: Icons.my_location_rounded,
          label: 'depots.detail.coordinates'.tr,
          // (0, 0) is how a depot with no fix is stored — not a place.
          value: depot.hasCoordinates
              ? '${depot.latitude.toStringAsFixed(6)}, '
                  '${depot.longitude.toStringAsFixed(6)}'
              : _orNull(null),
          onTap: depot.hasCoordinates
              ? () => onLocationTap(depot.latitude, depot.longitude)
              : null,
          last: true,
        ),
      ],
    );
  }
}

/// The stored list type as the rep reads it; awaiting approval says so.
String? _typeLabel(String? depotType) {
  String t(String key) => 'add_depot.registration_type.$key'.tr;
  return switch (depotType) {
    DepotTypes.depot => t('depot'),
    DepotTypes.nonDepot => t('non_bp'),
    DepotTypes.draft => '${t('depot')} · ${'depots.awaiting.audience'.tr}',
    DepotTypes.nonDepotDraft =>
      '${t('non_bp')} · ${'depots.awaiting.audience'.tr}',
    _ => depotType,
  };
}
