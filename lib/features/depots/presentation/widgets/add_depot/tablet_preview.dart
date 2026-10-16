part of '../add_depot_bottom_sheet.dart';

/// Tablet preview (stage 4). Split out of tablet_layout.dart for size.
extension _TabletPreviewExtension on _AddDepotBottomSheetState {
  Widget _buildTabletPreviewScreen(BpDepotDraft draft) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final needsCredit =
        SapMasterData.paymentTermNeedsCreditApproval(draft.paymentTerm);

    Widget previewItem(String label, String value, {bool isCode = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: _fontSize(12),
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  fontSize: _fontSize(13),
                  fontWeight: isCode ? FontWeight.w700 : FontWeight.w500,
                  color: colors.textPrimary,
                  fontFamily: isCode ? 'monospace' : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget previewCard({
      required String title,
      required IconData icon,
      required VoidCallback onEdit,
      required List<Widget> children,
    }) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: scheme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: _fontSize(15),
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label:
                      Text('Edit', style: TextStyle(fontSize: _fontSize(12))),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );
    }

    final formattedAddress = [
      if (draft.street.isNotEmpty || draft.houseNumber.isNotEmpty)
        '${draft.houseNumber} ${draft.street}'.trim(),
      if (draft.geoAddress != null && draft.geoAddress != GeoAddress.empty)
        draft.geoAddress!
            .format(LocalizationService.instance.currentLanguageCode)
      else ...[
        if (draft.communeCode != null) draft.communeCode!,
        if (draft.districtCode != null) draft.districtCode!,
        if (draft.cityCode != null) draft.cityCode!,
      ],
      if (draft.postalCode.isNotEmpty) 'Postal: ${draft.postalCode}',
    ].where((s) => s.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Highlight Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: 0.08),
                scheme.secondary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.nameEn.isNotEmpty ? draft.nameEn : 'New Depot',
                      style: TextStyle(
                        fontSize: _fontSize(18),
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (draft.nameKh.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        draft.nameKh,
                        style: TextStyle(
                          fontSize: _fontSize(14),
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: needsCredit
                      ? Colors.amber.withValues(alpha: 0.15)
                      : colors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: needsCredit ? Colors.amber : colors.success,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      needsCredit ? Icons.schedule : Icons.check_circle,
                      size: 16,
                      color:
                          needsCredit ? Colors.amber.shade900 : colors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      needsCredit
                          ? 'Credit Approval Required'
                          : 'Ready for SAP HQ',
                      style: TextStyle(
                        fontSize: _fontSize(12),
                        fontWeight: FontWeight.w800,
                        color: needsCredit
                            ? Colors.amber.shade900
                            : colors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _spacing(20)),

        // 2-Column Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  previewCard(
                    title: 'add_depot.steps.identity'.tr,
                    icon: Icons.person_outline_rounded,
                    onEdit: () => _editFromPreview(0, BpFormStep.identity),
                    children: [
                      previewItem('Account Group', draft.grouping,
                          isCode: true),
                      previewItem(
                          'Title', draft.title.isNotEmpty ? draft.title : '—'),
                      previewItem('Name (EN)', draft.nameEn),
                      if (draft.name2.isNotEmpty)
                        previewItem('Trade Name (Name 2)', draft.name2),
                      previewItem('Name (KH)', draft.nameKh),
                      previewItem('Search Term 1', draft.searchTerm),
                      if (draft.searchTerm2.isNotEmpty)
                        previewItem('Search Term 2', draft.searchTerm2),
                    ],
                  ),
                  SizedBox(height: _spacing(20)),
                  previewCard(
                    title: 'add_depot.steps.contact'.tr,
                    icon: Icons.phone_outlined,
                    onEdit: () => _editFromPreview(1, BpFormStep.contact),
                    children: [
                      // The person, then their number, then the shop's line.
                      // Listing the mobile first put it next to the landline
                      // and two rows away from the person it belongs to, which
                      // reads as two shop numbers rather than one of each.
                      previewItem('Contact Person', draft.contactPersonName),
                      previewItem(
                          'Contact Role', draft.contactPersonRole ?? '—'),
                      if (draft.contactCoName.isNotEmpty)
                        previewItem('c/o Name (to SAP)', draft.contactCoName),
                      previewItem('Mobile Phone', draft.mobilePhone),
                      previewItem(
                          'Telephone',
                          draft.telephoneSameAsMobile
                              ? 'Same as mobile'
                              : draft.telephone),
                      previewItem('Language', draft.language),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: _spacing(20)),
            Expanded(
              child: Column(
                children: [
                  previewCard(
                    title: 'add_depot.steps.address'.tr,
                    icon: Icons.location_on_outlined,
                    onEdit: () => _editFromPreview(0, BpFormStep.address),
                    children: [
                      previewItem('Full Address', formattedAddress),
                      if (draft.geoFix != null)
                        previewItem(
                          'GPS Coordinates',
                          '${draft.geoFix!.latitude.toStringAsFixed(5)}, ${draft.geoFix!.longitude.toStringAsFixed(5)}',
                          isCode: true,
                        ),
                    ],
                  ),
                  SizedBox(height: _spacing(20)),
                  previewCard(
                    title: 'add_depot.steps.sales_terms'.tr,
                    icon: Icons.receipt_long_outlined,
                    onEdit: () => _editFromPreview(1, BpFormStep.salesTerms),
                    children: [
                      previewItem('Distribution Channel',
                          draft.distributionChannel ?? '—'),
                      previewItem('Division', draft.divisionCode ?? '—'),
                      previewItem('Depot Group', draft.depotGroup ?? '—'),
                      previewItem('Price Group', draft.priceGroup ?? '—'),
                      previewItem(
                          'Delivery Priority', draft.deliveryPriority ?? '—'),
                      previewItem(
                          'Shipping Condition', draft.shippingCondition ?? '—'),
                      previewItem('Payment Terms', draft.paymentTerm ?? '—'),
                      previewItem(
                          'Tax Class',
                          draft.taxClass == '1'
                              ? '1 - Taxable'
                              : '0 - Non-taxable'),
                      if (draft.taxClass == '1')
                        previewItem('VAT / TIN', draft.vatTin, isCode: true),
                    ],
                  ),
                  SizedBox(height: _spacing(20)),
                  previewCard(
                    title: 'add_depot.steps.documents'.tr,
                    icon: Icons.folder_shared_outlined,
                    onEdit: () => _editFromPreview(2, BpFormStep.documents),
                    children: [
                      previewItem('Attachments',
                          '${draft.attachments.length} attached (${draft.attachments.map((a) => a.kind).join(', ')})'),
                      if (draft.remark.isNotEmpty)
                        previewItem('Remarks', draft.remark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
