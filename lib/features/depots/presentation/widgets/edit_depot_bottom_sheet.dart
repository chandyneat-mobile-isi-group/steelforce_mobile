import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// Modal bottom sheet to edit an existing Depot's platform-owned details.
///
/// Implements the field sales specification from `docs/feature/depot/mobile/edit-depot.md`:
/// - Editable: Shop Name, Khmer Name, Owner, Phone, WhatsApp, Address, GPS coordinates.
/// - Locked: SAP ID, Depot Code, Group, Sales Org, Division (managed strictly by SAP ERP).
/// - Closed check: Depots in [DepotStatus.closed] cannot be edited (Depot.Closed / 422).
class EditDepotBottomSheet extends StatefulWidget {
  const EditDepotBottomSheet({
    super.key,
    required this.depot,
    required this.onSave,
  });

  final Depot depot;
  final Future<void> Function(Depot updated) onSave;

  @override
  State<EditDepotBottomSheet> createState() => _EditDepotBottomSheetState();
}

class _EditDepotBottomSheetState extends State<EditDepotBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _shopNameController;
  late final TextEditingController _khNameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _addressController;
  late final TextEditingController _districtController;
  late final TextEditingController _provinceController;

  late double _latitude;
  late double _longitude;
  bool _isSaving = false;

  bool get _isClosed => widget.depot.status == DepotStatus.closed;

  @override
  void initState() {
    super.initState();
    final d = widget.depot;
    _shopNameController = TextEditingController(text: d.shopName);
    _khNameController = TextEditingController(text: d.khName ?? '');
    _ownerNameController = TextEditingController(text: d.ownerName);
    _phoneController = TextEditingController(text: d.phone);
    _whatsappController = TextEditingController(text: d.whatsapp ?? '');
    _addressController = TextEditingController(text: d.address);
    _districtController = TextEditingController(text: d.district);
    _provinceController = TextEditingController(text: d.province);
    _latitude = d.latitude;
    _longitude = d.longitude;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _khNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isClosed) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final updated = widget.depot.copyWith(
        shopName: _shopNameController.text.trim(),
        enName: _shopNameController.text.trim(),
        khName: _khNameController.text.trim().isEmpty
            ? null
            : _khNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        address: _addressController.text.trim(),
        district: _districtController.text.trim(),
        province: _provinceController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        updatedAt: DateTime.now(),
      );

      await widget.onSave(updated);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(8),
        context.pagePadding,
        context.rh(24),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: context.rr(40),
                  height: context.rr(40),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                  child: Icon(
                    Icons.edit_location_alt_rounded,
                    color: Colors.orange.shade800,
                    size: context.rr(22),
                  ),
                ),
                SizedBox(width: context.rw(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'depots.edit.title'.tr,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(17),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: context.rh(2)),
                      Text(
                        widget.depot.depotCode.isNotEmpty
                            ? widget.depot.depotCode
                            : (widget.depot.sapDepotId ??
                                'depots.edit.profile_fallback'.tr),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: context.rh(14)),

            // Terminal Closed Warning
            if (_isClosed) ...[
              Container(
                padding: EdgeInsets.all(context.rr(12)),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.rr(12)),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_clock_rounded,
                      color: scheme.error,
                      size: context.rr(20),
                    ),
                    SizedBox(width: context.rw(10)),
                    Expanded(
                      child: Text(
                        'depots.edit.closed_notice'.tr,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: context.rsp(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.rh(14)),
            ],

            // Scrollable fields
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section: Outlet Identity
                    _SectionTitle(
                      title: 'depots.edit.section_identity'.tr,
                      icon: Icons.storefront_outlined,
                    ),
                    SizedBox(height: context.rh(8)),
                    _TextFormField(
                      controller: _shopNameController,
                      label: 'depots.edit.shop_name'.tr,
                      hint: 'depots.edit.shop_name_hint'.tr,
                      enabled: !_isClosed,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'depots.edit.shop_name_required'.tr
                          : null,
                    ),
                    SizedBox(height: context.rh(10)),
                    _TextFormField(
                      controller: _khNameController,
                      label: 'depots.edit.shop_name_km'.tr,
                      hint: 'depots.edit.shop_name_km_hint'.tr,
                      enabled: !_isClosed,
                    ),
                    SizedBox(height: context.rh(10)),
                    _TextFormField(
                      controller: _ownerNameController,
                      label: 'depots.edit.owner'.tr,
                      hint: 'depots.edit.owner_hint'.tr,
                      enabled: !_isClosed,
                    ),

                    SizedBox(height: context.rh(18)),

                    // Section: Contact Information
                    _SectionTitle(
                      title: 'depots.edit.section_contact'.tr,
                      icon: Icons.call_outlined,
                    ),
                    SizedBox(height: context.rh(8)),
                    _TextFormField(
                      controller: _phoneController,
                      label: 'depots.edit.phone'.tr,
                      hint: 'depots.edit.phone_hint'.tr,
                      keyboardType: TextInputType.phone,
                      enabled: !_isClosed,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'depots.edit.phone_required'.tr
                          : null,
                    ),
                    SizedBox(height: context.rh(10)),
                    _TextFormField(
                      controller: _whatsappController,
                      label: 'WhatsApp / Telegram',
                      hint: 'depots.edit.messaging_hint'.tr,
                      enabled: !_isClosed,
                    ),

                    SizedBox(height: context.rh(18)),

                    // Section: Address & Location
                    _SectionTitle(
                      title: 'depots.edit.section_location'.tr,
                      icon: Icons.location_on_outlined,
                    ),
                    SizedBox(height: context.rh(8)),
                    _TextFormField(
                      controller: _addressController,
                      label: 'depots.edit.street'.tr,
                      hint: 'depots.edit.street_hint'.tr,
                      enabled: !_isClosed,
                    ),
                    SizedBox(height: context.rh(10)),
                    Row(
                      children: [
                        Expanded(
                          child: _TextFormField(
                            controller: _districtController,
                            label: 'depots.edit.district'.tr,
                            hint: 'depots.edit.district_hint'.tr,
                            enabled: !_isClosed,
                          ),
                        ),
                        SizedBox(width: context.rw(10)),
                        Expanded(
                          child: _TextFormField(
                            controller: _provinceController,
                            label: 'depots.edit.province'.tr,
                            hint: 'depots.edit.province_hint'.tr,
                            enabled: !_isClosed,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rh(10)),

                    // Coordinates Display
                    Container(
                      padding: EdgeInsets.all(context.rr(12)),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(context.rr(12)),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.gps_fixed_rounded,
                            size: context.rr(18),
                            color: scheme.primary,
                          ),
                          SizedBox(width: context.rw(10)),
                          Expanded(
                            child: Text(
                              'depots.edit.gps'.trParams({
                                'lat': _latitude.toStringAsFixed(5),
                                'lng': _longitude.toStringAsFixed(5),
                              }),
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.rh(18)),

                    // Section: Locked ERP Master Data
                    _LockedSapSection(depot: widget.depot),
                  ],
                ),
              ),
            ),

            SizedBox(height: context.rh(16)),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rr(12)),
                      ),
                    ),
                    child: Text(
                      'common.cancel'.tr,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.rw(12)),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isClosed || _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rr(12)),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: context.rr(20),
                            height: context.rr(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Text(
                            'common.save_changes'.tr,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(icon, size: context.rr(16), color: colors.textSecondary),
        SizedBox(width: context.rw(6)),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(13),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TextFormField extends StatelessWidget {
  const _TextFormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: context.rsp(14),
        color: enabled ? colors.textPrimary : colors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: enabled ? colors.card : colors.surfaceSoft,
        labelStyle: TextStyle(
          fontSize: context.rsp(13),
          color: colors.textSecondary,
        ),
        hintStyle: TextStyle(
          fontSize: context.rsp(13),
          color: colors.textSecondary.withValues(alpha: 0.6),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.rw(14),
          vertical: context.rh(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _LockedSapSection extends StatelessWidget {
  const _LockedSapSection({required this.depot});

  final Depot depot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: context.rr(15),
                color: colors.textSecondary,
              ),
              SizedBox(width: context.rw(6)),
              Text(
                'depots.edit.sap_managed'.tr,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(8)),
          _LockedTile(
            label: 'depots.edit.sap_depot_code'.tr,
            value: depot.depotCode,
          ),
          _LockedTile(
            label: 'depots.detail.sap_id'.tr,
            value: depot.sapDepotId ?? 'depots.edit.pending'.tr,
          ),
          _LockedTile(
            label: 'depots.edit.depot_group'.tr,
            value: depot.depotGroup ?? 'depots.edit.standard'.tr,
          ),
          _LockedTile(
            label: 'depots.edit.sales_org_division'.tr,
            value: '${depot.salesOrg ?? "—"} / ${depot.division ?? "—"}',
          ),
        ],
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: context.rsp(11),
              color: colors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: context.rsp(11),
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
