import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';
import 'package:phone_form_field/phone_form_field.dart';

import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/presentation/bloc/add_depot_bloc.dart';
import 'package:steelforce/features/geo_location/domain/entities/geo_address.dart';
import 'package:steelforce/features/geo_location/domain/usecases/resolve_geo_address.dart';
import 'package:steelforce/features/geo_location/presentation/widgets/geo_location_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/features/order/domain/services/order_location_service.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_submit_progress_dialog.dart';
import 'package:steelforce/features/depots/domain/entities/bp_attachment.dart';
import 'package:steelforce/features/depots/domain/entities/geo_fix.dart';
import 'package:steelforce/features/depots/domain/entities/sap_bp_const.dart';
import 'package:steelforce/features/depots/domain/entities/sap_master_data.dart';
import 'package:steelforce/features/depots/domain/entities/sap_option.dart';

part 'add_depot/shared_components.dart';
part 'add_depot/shared_selectors.dart';
part 'add_depot/shared_tiles.dart';
part 'add_depot/mobile_layout.dart';
part 'add_depot/tablet_layout.dart';
part 'add_depot/tablet_header.dart';
part 'add_depot/tablet_preview.dart';
part 'add_depot/identity_step.dart';
part 'add_depot/address_step.dart';
part 'add_depot/contact_step.dart';
part 'add_depot/sales_terms_step.dart';
part 'add_depot/documents_step.dart';
part 'add_depot/review_step.dart';

/// Console tracer, sharing the registration channel so the form's own steps
/// interleave with the bloc's and the HTTP calls' in one readable sequence.
const _trace = DebugTrace('registration');

class AddDepotBottomSheet extends StatelessWidget {
  final bool isTablet;
  final bool isFullScreen;

  const AddDepotBottomSheet({
    super.key,
    this.isTablet = false,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) => BlocProvider<AddDepotBloc>(
        create: (_) => sl<AddDepotBloc>()..add(const OpenForm()),
        child: _AddDepotForm(
          isTablet: isTablet,
          isFullScreen: isFullScreen,
        ),
      );
}

class _AddDepotForm extends StatefulWidget {
  const _AddDepotForm({
    required this.isTablet,
    required this.isFullScreen,
  });
  final bool isTablet;
  final bool isFullScreen;

  @override
  State<_AddDepotForm> createState() => _AddDepotBottomSheetState();
}

class _AddDepotBottomSheetState extends State<_AddDepotForm> {
  // Simulator-only fallback used while developing the Cambodia sales app.
  // Release builds must always store the real device position.
  static const _developmentCambodiaLatitude = 11.5564;
  static const _developmentCambodiaLongitude = 104.9282;

  // ---------------------------------------------------------------------------
  // Controllers exist ONLY for text input. Every value lives on the draft;
  // the controllers write through to it on change.
  // ---------------------------------------------------------------------------
  final _nameEnCtrl = TextEditingController();
  final _nameKhCtrl = TextEditingController();
  final _name2Ctrl = TextEditingController();
  final _searchTermCtrl = TextEditingController();
  final _searchTerm2Ctrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNoCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _vatTinCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  final _mobileCtrl = PhoneController(
      initialValue: const PhoneNumber(isoCode: IsoCode.KH, nsn: ''));
  final _telCtrl = PhoneController(
      initialValue: const PhoneNumber(isoCode: IsoCode.KH, nsn: ''));

  /// Lets "Next" tell the address block to reveal its own field errors.
  ///
  /// `validateStep` decides whether the step may advance, but it returns error
  /// keys the geo selector never sees — it owns its four fields and their
  /// messages. Without this handle the rep taps Next, nothing happens, and no
  /// field says why.
  final _geoController = GeoLocationSelectorController();

  /// The address-step error keys the selector renders itself. Postal code is
  /// included: the selector owns that field too, including the manual-entry
  /// case for the communes with no code on record.
  static const _geoErrorKeys = {'city', 'district', 'commune', 'postalCode'};

  bool _capturingGps = false;
  bool _showMoreIdentity = false;
  bool _showAdvancedTerms = false;

  /// False between `deactivate` and `activate`/`dispose`. A bloc listener can
  /// still fire in that window — the app restarting under an open sheet
  /// (sign-out, language change) — and every tree lookup it makes (navigator,
  /// theme, messenger) then throws "Looking up a deactivated widget's
  /// ancestor is unsafe". `mounted` stays true there, so it cannot be used.
  bool _inTree = true;

  @override
  void activate() {
    super.activate();
    _inTree = true;
  }

  @override
  void deactivate() {
    _inTree = false;
    super.deactivate();
  }

  @override
  void dispose() {
    for (final c in [
      _nameEnCtrl,
      _nameKhCtrl,
      _name2Ctrl,
      _searchTermCtrl,
      _searchTerm2Ctrl,
      _streetCtrl,
      _houseNoCtrl,
      _contactNameCtrl,
      _vatTinCtrl,
      _remarkCtrl,
    ]) {
      c.dispose();
    }
    _mobileCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  double _fontSize(double base) =>
      widget.isTablet ? base * 1.25 : context.rsp(base);

  double _spacing(double base) =>
      widget.isTablet ? base * 1.2 : context.rh(base);

  bool get _isTabletLayout =>
      widget.isTablet ||
      context.responsive(compact: false, medium: true, expanded: true);

  int _tabletStage =
      0; // 0: Identity+Address, 1: Contact+Terms, 2: Documents+Notes, 3: Preview

  AddDepotBloc get _bloc => context.read<AddDepotBloc>();

  /// Guards the "resumed your draft" notice so it shows once when the form
  /// opens, not again on every later rebuild — the listener also fires on
  /// every edit.
  bool _resumeNoticeShown = false;

  /// True while the submit progress dialog is on the navigator.
  ///
  /// Tracked rather than inferred from `state.status`, because the dialog is
  /// popped by route and pushing a second one — or popping the sheet itself by
  /// mistake — is exactly the failure this guards.
  bool _progressDialogVisible = false;

  /// Single mutation entry point. Everything the rep touches goes through here.
  void _edit(void Function(BpDepotDraft d) mutate) =>
      _bloc.add(DraftChanged(mutate));

  void _syncTextControllers(BpDepotDraft draft) {
    // A resumed draft and the derived fields (both search terms) are written
    // by the bloc rather than typed, so copy the draft's values into the
    // visible controls.
    _nameEnCtrl.text = draft.nameEn;
    _nameKhCtrl.text = draft.nameKh;
    _name2Ctrl.text = draft.name2;
    _searchTermCtrl.text = draft.searchTerm;
    _searchTerm2Ctrl.text = draft.searchTerm2;
    _streetCtrl.text = draft.street;
    _houseNoCtrl.text = draft.houseNumber;
    _contactNameCtrl.text = draft.contactPersonName;
    _vatTinCtrl.text = draft.vatTin;
    _remarkCtrl.text = draft.remark;
  }

  // ===========================================================================
  // Build
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BlocConsumer<AddDepotBloc, AddDepotState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.draft != curr.draft ||
          prev.errors != curr.errors,
      listener: (context, state) {
        if (!_inTree) return;
        // No draft-id gate any more: the form is local until submit, so it is
        // editable from the first frame.
        if (state.status == AddDepotStatus.editing) {
          _syncTextControllers(state.draft);

          // Say why the form came back filled in. Without this the rep sees
          // their own earlier typing and cannot tell whether it is stale data
          // from someone else's record.
          if (state.resumedDraft && !_resumeNoticeShown) {
            _resumeNoticeShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('add_depot.draft_resumed'.tr)),
            );
          }
        }
        // Next was blocked on a field the selector owns — tell it to show why.
        if (state.currentStep == BpFormStep.address &&
            state.errors.keys.any(_geoErrorKeys.contains)) {
          _geoController.validate();
        }
        if (state.errors.isNotEmpty && _isTabletLayout) {
          if (state.currentStep == BpFormStep.identity ||
              state.currentStep == BpFormStep.address) {
            setState(() => _tabletStage = 0);
          } else if (state.currentStep == BpFormStep.contact ||
              state.currentStep == BpFormStep.salesTerms) {
            setState(() => _tabletStage = 1);
          } else if (state.currentStep == BpFormStep.documents) {
            setState(() => _tabletStage = 2);
          }
        }
        // Progress dialog: shown once when the submit starts, and torn down on
        // whichever terminal state arrives. Driven from the listener rather
        // than the builder so it survives the rebuilds the form does while
        // uploading.
        if (state.status == AddDepotStatus.submitting &&
            !_progressDialogVisible) {
          _progressDialogVisible = true;

          // Captured here, not looked up inside the builder.
          //
          // `showDialog` builds its child from a context on the Navigator's
          // overlay, which sits *above* the `BlocProvider` the create screen
          // supplies — so a `BlocBuilder` in there finds no provider and
          // throws `ProviderNotFoundException`. Handing the instance across
          // with `BlocProvider.value` is what re-attaches it.
          //
          // `.value`, never `create`: this bloc is owned by the screen and
          // must not be closed when the dialog pops.
          final bloc = _bloc;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            routeSettings:
                const RouteSettings(name: DepotSubmitProgressDialog.routeName),
            builder: (_) => BlocProvider<AddDepotBloc>.value(
              value: bloc,
              child: BlocBuilder<AddDepotBloc, AddDepotState>(
                // Only the progress moves while this is up; rebuilding on every
                // field change would be wasted work behind a modal barrier.
                buildWhen: (a, b) => a.progress != b.progress,
                builder: (_, s) =>
                    DepotSubmitProgressDialog(progress: s.progress),
              ),
            ),
          );
        }
        if (_progressDialogVisible &&
            state.status != AddDepotStatus.submitting) {
          _progressDialogVisible = false;
          // Pop the dialog, never the sheet: `PopScope` blocks the back
          // gesture, so this is the only route out and it must target exactly
          // the dialog.
          Navigator.of(context).popUntil((route) =>
              route.settings.name != DepotSubmitProgressDialog.routeName);
        }

        if (state.status == AddDepotStatus.success) {
          // The depot is saved either way. An evidence slot that did not
          // reach the server is reported here rather than as a failure,
          // because the registration itself succeeded — but staying silent
          // would leave the rep believing photographs were filed that are not.
          final unsent = state.unsentDocuments.length;
          final message = switch (state) {
            // Sent, but no answer came back: not resent automatically, because
            // SAP may already hold it. The Sync Center asks the rep to check.
            _ when state.queuedNeedsReview =>
              'add_depot.queued_needs_review'.tr,
            _ when state.queuedOffline => 'add_depot.queued_offline'.tr,
            _ when unsent > 0 =>
              'add_depot.documents_partially_sent'.trParams({'count': unsent}),
            // "Sent for approval" and "depot 0000123456 created" are
            // different promises. Showing the second when the first is true is
            // how a rep comes to believe they can order against the shop
            // today, and the order is then rejected in front of the depot.
            _ when state.awaitingApproval =>
              'add_depot.success_pending_approval'.tr,
            _ => state.depotNumber == null || state.depotNumber!.isEmpty
                ? 'add_depot.success'.tr
                : 'add_depot.success_with_code'
                    .trParams({'code': state.depotNumber!}),
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: state.queuedNeedsReview ||
                      (unsent > 0 && !state.queuedOffline)
                  ? context.appColors.warning
                  : null,
              duration: unsent > 0 || state.queuedNeedsReview
                  ? const Duration(seconds: 6)
                  : const Duration(seconds: 4),
              content: Text(message),
            ),
          );
          Navigator.pop(context, true);
        } else if (state.status == AddDepotStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.error,
              content:
                  Text((state.errorMessage ?? 'add_depot.error.submit').tr),
            ),
          );
        }
      },
      builder: (context, state) {
        final hasKeyboard = bottomInset > 0;
        final bottomPadding = hasKeyboard
            ? context.rh(8)
            : (widget.isTablet
                ? 24.0
                : context.deviceInsets.safeBottom + context.rh(8));

        return LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: double.infinity,
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Area (Transparent, sits over the blue gradient)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.isTablet ? 36 : context.rw(16),
                      widget.isTablet ? 20 : context.rh(12),
                      widget.isTablet ? 36 : context.rw(16),
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.isFullScreen) ...[
                          Center(
                            child: Container(
                              width: widget.isTablet ? 60 : context.rw(42),
                              height: widget.isTablet ? 6 : context.rh(5),
                              decoration: BoxDecoration(
                                color: context.appColors.border,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          SizedBox(height: _spacing(8)),
                        ],
                        if (_isTabletLayout) ...[
                          _buildTabletFormHeader(state),
                          SizedBox(height: _spacing(12)),
                          _buildTabletStepProgress(state),
                          SizedBox(height: _spacing(12)),
                        ] else ...[
                          _buildFormHeader(state),
                          SizedBox(height: _spacing(10)),
                        ],
                      ],
                    ),
                  ),
                  // Form Area (White sheet with rounded top corners)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: widget.isFullScreen
                            ? const BorderRadius.vertical(
                                top: Radius.circular(28))
                            : BorderRadius.vertical(
                                top: Radius.circular(
                                    widget.isTablet ? 24 : context.rr(24)),
                              ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        widget.isTablet ? 36 : context.rw(16),
                        widget.isTablet ? 20 : context.rh(12),
                        widget.isTablet ? 36 : context.rw(16),
                        bottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isTabletLayout) ...[
                            _buildStepProgress(state),
                            const SizedBox(height: 4),
                            _buildSectionHeader(state),
                            const SizedBox(height: 6),
                          ],
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(bottom: context.rh(12)),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeInOut,
                                switchOutCurve: Curves.easeInOut,
                                child: state.isBusy
                                    ? Center(
                                        key:
                                            const ValueKey('submitting_loader'),
                                        child: Padding(
                                          padding: EdgeInsets.all(_spacing(40)),
                                          child: CircularProgressIndicator(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                      )
                                    : _isTabletLayout
                                        ? KeyedSubtree(
                                            key: ValueKey(
                                                'tablet_stage_$_tabletStage'),
                                            child: _buildTabletStageBody(state),
                                          )
                                        : KeyedSubtree(
                                            key: ValueKey(state.currentStep),
                                            child: _buildStepBody(
                                                state.currentStep,
                                                state.errors),
                                          ),
                              ),
                            ),
                          ),
                          SizedBox(height: _spacing(10)),
                          if (_isTabletLayout)
                            _buildTabletNavigationButtons(state)
                          else
                            _buildNavigationButtons(state),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // Step router — mirrors BpFormStep exactly
  // ===========================================================================
  Widget _buildStepBody(BpFormStep step, Map<String, String> errors) {
    return switch (step) {
      BpFormStep.identity => _buildIdentityStep(errors),
      BpFormStep.address => _buildAddressStep(errors),
      BpFormStep.contact => _buildContactStep(errors),
      BpFormStep.salesTerms => _buildSalesTermsStep(errors),
      BpFormStep.documents => _buildDocumentsStep(errors),
      BpFormStep.review => _buildReviewStep(errors),
    };
  }
}
