import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/data/datasources/non_bp_depot_demo_data.dart';

part 'non_bp_register/form_fields.dart';
part 'non_bp_register/linked_depot_picker.dart';

/// Registers a party that buys through one of our SAP depots.
///
/// **Demo only.** Nothing is validated against the server, nothing is saved and
/// nothing reaches SAP. Save shows a confirmation and pops.
///
/// **Why this form is short.** Depot registration collects a business-partner
/// block, a sales area, credit terms and five photographs, because SAP will
/// refuse to create a depot master without them. None of that applies here:
/// a non-bp-depot is never invoiced, so there is no ledger to place them in and
/// no ERP record to keep in step. Asking for it anyway would be a ten-minute
/// form for a record that carries no commercial weight — and a rep standing in
/// a yard would simply not fill it in.
///
/// What is left is identity and one link. The link is the point: it decides
/// which dealer's volume this party's purchases roll up to.
class NonBpDepotRegisterScreen extends StatefulWidget {
  const NonBpDepotRegisterScreen({super.key});

  static const routeName = 'non-bp-depot-register';

  @override
  State<NonBpDepotRegisterScreen> createState() =>
      _NonBpDepotRegisterScreenState();
}

class _NonBpDepotRegisterScreenState extends State<NonBpDepotRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _identityController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  NonBpDepotKind _kind = NonBpDepotKind.subDealer;
  LinkableDepotDemo? _linkedDepot;

  /// Set when Save is pressed without a linked depot.
  ///
  /// Tracked separately from the form's own validators because the link is not
  /// a text field — a `FormField` wrapper would work and would put a validation
  /// concern inside a picker that has no other reason to know about forms.
  bool _linkMissing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _identityController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickLinkedDepot() async {
    final picked = await showModalBottomSheet<LinkableDepotDemo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LinkedDepotPicker(),
    );

    if (picked != null && mounted) {
      setState(() {
        _linkedDepot = picked;
        _linkMissing = false;
      });
    }
  }

  void _submit() {
    final formValid = _formKey.currentState?.validate() ?? false;
    final linkChosen = _linkedDepot != null;

    setState(() => _linkMissing = !linkChosen);

    if (!formValid || !linkChosen) {
      // Both are checked before returning so a rep missing two things is told
      // about two things. Reporting the first failure only means a second
      // round trip through the form for a fault that was already visible.
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo screen — nothing was saved.')),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Register Non-BP Depot'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              context.rw(16),
              context.rh(12),
              context.rw(16),
              context.rh(24),
            ),
            children: [
              const _DemoNotice(),
              SizedBox(height: context.rh(20)),

              // Identity first. It is what the rep is looking at while they
              // type, and a form that opens on an abstract classification
              // before the name reads as paperwork rather than a record of
              // somebody standing in front of them.
              const _SectionLabel('Identity'),
              SizedBox(height: context.rh(10)),
              _Field(
                label: 'Name',
                required: true,
                controller: _nameController,
                hint: 'Shop, company or person',
                textCapitalization: TextCapitalization.words,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'A name is required'
                    : null,
              ),
              SizedBox(height: context.rh(14)),
              _KindPicker(
                selected: _kind,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
              SizedBox(height: context.rh(14)),
              _Field(
                label: 'Phone',
                required: true,
                controller: _phoneController,
                hint: '012 345 678',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'A phone number is required'
                    : null,
              ),
              SizedBox(height: context.rh(14)),
              _Field(
                label: 'ID or licence number',
                controller: _identityController,
                hint: 'National ID, or business licence',
                // Optional, and said so on the label rather than only in a
                // validator. A sub-dealer met at a roadside yard often will not
                // produce one, and a required field here means the record is
                // never created at all — worse than a record without an ID.
                helper: 'Optional. Leave blank if none was shown.',
              ),
              SizedBox(height: context.rh(14)),
              _Field(
                label: 'Location',
                required: true,
                controller: _locationController,
                hint: 'District, province',
                textCapitalization: TextCapitalization.words,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'A location is required'
                    : null,
              ),

              SizedBox(height: context.rh(26)),
              const _SectionLabel('Linked SAP depot'),
              SizedBox(height: context.rh(6)),
              Text(
                'Purchases by this party are counted against the depot you '
                'pick here. Without it the record has nowhere to report to.',
                style: TextStyle(
                  fontSize: context.rsp(11.5),
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: context.rh(10)),
              _LinkedDepotField(
                depot: _linkedDepot,
                showError: _linkMissing,
                onTap: _pickLinkedDepot,
              ),

              SizedBox(height: context.rh(26)),
              const _SectionLabel('Note'),
              SizedBox(height: context.rh(10)),
              _Field(
                label: 'What they buy',
                controller: _noteController,
                hint: 'Roofing sheet weekly, rebar for a project…',
                maxLines: 3,
                helper: 'Optional.',
              ),

              SizedBox(height: context.rh(28)),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: context.rh(15)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save non depot',
                    style: TextStyle(
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
