import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot/edit_depot_actions.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot/edit_depot_form_parts.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot/edit_depot_header.dart';
import 'package:steelforce/features/depots/presentation/widgets/edit_depot/locked_sap_section.dart';

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
    final enabled = !_isClosed;

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
            EditDepotHeader(depot: widget.depot),
            SizedBox(height: context.rh(14)),
            if (_isClosed) ...[
              const EditDepotClosedNotice(),
              SizedBox(height: context.rh(14)),
            ],
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EditDepotSectionTitle(
                      title: 'Outlet Identity',
                      icon: Icons.storefront_outlined,
                    ),
                    SizedBox(height: context.rh(8)),
                    EditDepotTextField(
                      controller: _shopNameController,
                      label: 'Shop / Outlet Name (EN)*',
                      hint: 'e.g. Sok Heng Hardware',
                      enabled: enabled,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Shop name is required'
                          : null,
                    ),
                    SizedBox(height: context.rh(10)),
                    EditDepotTextField(
                      controller: _khNameController,
                      label: 'Shop Name (Khmer)',
                      hint: 'e.g. ហាង សុខ ហេង',
                      enabled: enabled,
                    ),
                    SizedBox(height: context.rh(10)),
                    EditDepotTextField(
                      controller: _ownerNameController,
                      label: 'Owner / Contact Person',
                      hint: 'e.g. Sok Heng',
                      enabled: enabled,
                    ),
                    SizedBox(height: context.rh(18)),
                    const EditDepotSectionTitle(
                      title: 'Contact Information',
                      icon: Icons.call_outlined,
                    ),
                    SizedBox(height: context.rh(8)),
                    EditDepotTextField(
                      controller: _phoneController,
                      label: 'Primary Phone Number*',
                      hint: 'e.g. 012 345 678',
                      keyboardType: TextInputType.phone,
                      enabled: enabled,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Phone number is required'
                          : null,
                    ),
                    SizedBox(height: context.rh(10)),
                    EditDepotTextField(
                      controller: _whatsappController,
                      label: 'WhatsApp / Telegram',
                      hint: 'e.g. +85512345678 or @handle',
                      enabled: enabled,
                    ),
                    SizedBox(height: context.rh(18)),
                    const EditDepotSectionTitle(
                      title: 'Location & Address',
                      icon: Icons.location_on_outlined,
                    ),
                    SizedBox(height: context.rh(8)),
                    EditDepotTextField(
                      controller: _addressController,
                      label: 'Street Address',
                      hint: 'e.g. Street 271, Sangkat Phsar Deum Thkov',
                      enabled: enabled,
                    ),
                    SizedBox(height: context.rh(10)),
                    Row(
                      children: [
                        Expanded(
                          child: EditDepotTextField(
                            controller: _districtController,
                            label: 'District / Khan',
                            hint: 'e.g. Chamkarmon',
                            enabled: enabled,
                          ),
                        ),
                        SizedBox(width: context.rw(10)),
                        Expanded(
                          child: EditDepotTextField(
                            controller: _provinceController,
                            label: 'Province / City',
                            hint: 'e.g. Phnom Penh',
                            enabled: enabled,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rh(10)),
                    DepotGpsTile(latitude: _latitude, longitude: _longitude),
                    SizedBox(height: context.rh(18)),
                    LockedSapSection(depot: widget.depot),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.rh(16)),
            EditDepotActions(
              isSaving: _isSaving,
              onSave: _isClosed || _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
