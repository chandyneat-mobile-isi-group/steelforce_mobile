part of '../depot_detail_screen.dart';

/// `profile.contactPersons`: each contact's name, position and phone, the
/// phone tappable. One "null" row when the API sent none.
class _ContactsSection extends StatelessWidget {
  const _ContactsSection({required this.depot, required this.onPhoneTap});

  final Depot depot;
  final Function(String) onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final contacts = depot.contacts;
    return _DetailSectionCard(
      title: 'depots.detail.section_contacts'.tr,
      children: [
        if (contacts.isEmpty)
          _CompactTile(
            icon: Icons.person_outline_rounded,
            label: 'depots.detail.contact_person'.tr,
            value: _orNull(null),
            last: true,
          ),
        for (final (i, contact) in contacts.indexed) ...[
          _CompactTile(
            icon: Icons.person_outline_rounded,
            label: 'depots.detail.contact_person'.tr,
            value: _orNull(contact.name),
          ),
          _CompactTile(
            icon: Icons.badge_outlined,
            label: 'depots.detail.position'.tr,
            value: _orNull(contact.role),
          ),
          _CompactTile(
            icon: Icons.phone_iphone_rounded,
            label: 'depots.detail.contact_phone'.tr,
            value: _orNull(contact.phone),
            last: i == contacts.length - 1,
            onTap: contact.phone.trim().isEmpty
                ? null
                : () => onPhoneTap(contact.phone.trim()),
          ),
        ],
      ],
    );
  }
}

/// `salesEmployees`: who sells to the depot. The API stopped sending it on
/// 30 Oct; every row reads "null" until it does again.
class _SalesTeamSection extends StatelessWidget {
  const _SalesTeamSection(this.depot);

  final Depot depot;

  @override
  Widget build(BuildContext context) {
    final employees = depot.salesEmployees ?? const <DepotSalesEmployee>[];
    final shown = employees.isEmpty ? const [DepotSalesEmployee()] : employees;
    String? both(String? code, String? name) {
      final parts = [code, name]
          .whereType<String>()
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty);
      return parts.isEmpty ? null : parts.join(' · ');
    }

    return _DetailSectionCard(
      title: 'depots.detail.section_sales_team'.tr,
      children: [
        for (final (i, e) in shown.indexed) ...[
          _CompactTile(
            icon: Icons.person_pin_outlined,
            label: 'depots.detail.employee'.tr,
            value: _orNull(both(e.employeeCode, e.employeeName)),
          ),
          _CompactTile(
            icon: Icons.map_outlined,
            label: 'depots.detail.territory'.tr,
            value: _orNull(both(e.territoryCode, e.territoryName)),
          ),
          _CompactTile(
            icon: Icons.account_tree_outlined,
            label: 'depots.detail.branch'.tr,
            value: _orNull(both(e.branchCode, e.branchName)),
          ),
          _CompactTile(
            icon: Icons.public_outlined,
            label: 'depots.detail.region'.tr,
            value: _orNull(both(e.regionCode, e.regionName)),
            last: i == shown.length - 1,
          ),
        ],
      ],
    );
  }
}

/// Who registered the depot and when — the API sends both for drafts.
class _AuditSection extends StatelessWidget {
  const _AuditSection(this.depot);

  final Depot depot;

  @override
  Widget build(BuildContext context) {
    final createdAt = depot.createdAt;
    return _DetailSectionCard(
      title: 'depots.detail.section_audit'.tr,
      children: [
        _CompactTile(
            icon: Icons.person_add_alt_outlined,
            label: 'depots.detail.created_by'.tr,
            value: _orNull(depot.createdBy)),
        _CompactTile(
          icon: Icons.event_outlined,
          label: 'depots.detail.created_at'.tr,
          value: _orNull(createdAt == null
              ? null
              : DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toLocal())),
          last: true,
        ),
      ],
    );
  }
}
