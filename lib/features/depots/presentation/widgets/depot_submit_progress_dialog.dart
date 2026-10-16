import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot_submit_progress.dart';

/// Shown while a registration is being submitted.
///
/// ## What it does not claim
///
/// There is no "sending to SAP" step, because submit does not call the ERP —
/// the record is written to the platform and an operator or scheduled job
/// delivers it later (`docs/feature/depot/mobile/create-depot.md`).
/// Animating an ERP call would tell a representative their shop is in SAP when
/// it is queued, and the difference is one they would act on: a rejected push
/// is the office's problem to fix, not theirs.
///
/// So the stages shown are the ones that really happen, and the ERP is
/// mentioned once, as a footnote saying the wait is not theirs.
///
/// Barrier-dismissible is off and there is no cancel: the create request is
/// already in flight and half of it cannot be recalled. The rep is told to keep
/// the screen open instead.
class DepotSubmitProgressDialog extends StatelessWidget {
  const DepotSubmitProgressDialog({super.key, required this.progress});

  final DepotSubmitProgress progress;

  /// Route name, so the dialog can be popped without capturing its context.
  static const String routeName = 'depot-submit-progress';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      // The request is in flight; a back gesture must not leave the rep on the
      // form believing nothing happened.
      canPop: false,
      child: Dialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rr(18)),
        ),
        // Bounded and scrollable rather than a bare Column: five stage rows, a
        // note and a footer overflow a short screen at a large font scale, and
        // the Definition of Done requires 200%. Capped at 80% of the viewport
        // so it stays a dialog rather than growing into a page.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.rr(22)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'add_depot.submit_progress.title'.tr,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: context.rsp(16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.rh(16)),

                // Determinate, because every stage is countable. An indeterminate
                // spinner on a five-photo upload looks identical to a hang.
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: context.rh(6),
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
                SizedBox(height: context.rh(16)),

                for (final stage in SubmitStage.values)
                  if (stage != SubmitStage.uploadingPhotos ||
                      progress.hasPhotos)
                    _StageRow(
                      label: _labelFor(stage),
                      state: _stateOf(stage),
                    ),

                SizedBox(height: context.rh(14)),
                Container(
                  padding: EdgeInsets.all(context.rr(12)),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: context.rr(16), color: colors.textSecondary),
                      SizedBox(width: context.rw(8)),
                      Expanded(
                        child: Text(
                          'add_depot.submit_progress.sap_note'.tr,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11.5),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.rh(10)),
                Center(
                  child: Text(
                    'add_depot.submit_progress.keep_open'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(SubmitStage stage) => switch (stage) {
        SubmitStage.validating => 'add_depot.submit_progress.validating'.tr,
        SubmitStage.registering => 'add_depot.submit_progress.registering'.tr,
        SubmitStage.uploadingPhotos => progress.hasPhotos
            ? 'add_depot.submit_progress.uploading_photos_count'.trParams({
                'sent': progress.photosSent,
                'total': progress.photosTotal,
              })
            : 'add_depot.submit_progress.uploading_photos'.tr,
        SubmitStage.finishing => 'add_depot.submit_progress.finishing'.tr,
      };

  _StageState _stateOf(SubmitStage stage) {
    if (stage.index < progress.stage.index) return _StageState.done;
    if (stage.index > progress.stage.index) return _StageState.pending;
    // The final stage is only ever emitted once the work is over, so showing it
    // as still spinning would leave the dialog looking stuck as it closes.
    return progress.stage == SubmitStage.finishing
        ? _StageState.done
        : _StageState.active;
  }
}

enum _StageState { done, active, pending }

/// One line of the checklist: a tick, a spinner, or a waiting dot.
class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});

  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final size = context.rr(16);

    final Widget leading = switch (state) {
      _StageState.done =>
        Icon(Icons.check_circle_rounded, size: size, color: colors.success),
      _StageState.active => SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        ),
      _StageState.pending => Icon(Icons.circle_outlined,
          size: size, color: colors.textSecondary.withValues(alpha: 0.4)),
    };

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.rh(5)),
      child: Row(
        children: [
          leading,
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: state == _StageState.pending
                    ? colors.textSecondary
                    : colors.textPrimary,
                fontSize: context.rsp(13),
                fontWeight: state == _StageState.active
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
