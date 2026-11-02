import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/plan_check_out_cubit.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/plan_check_out_state.dart';

/// **Complete the visit** on the inventory completion screen of a planned
/// visit — its check-out (`POST /api/v1/mobile/plans/{id}/check-out`) — with
/// optional free-text notes sent alongside. A refusal is shown under it and
/// the rep can tap again; the same check-out id makes that safe.
class PlanCheckOutButton extends StatefulWidget {
  const PlanCheckOutButton({
    super.key,
    required this.planId,
    required this.onCheckedOut,
  });

  final String planId;

  /// The visit is checked out: back to the Visits list, as Complete Visit
  /// does, so no Start Visit button for it is left behind — saying whether
  /// the check-out went now or waits on the device ([queued]).
  static void finish(BuildContext context, {required bool queued}) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    messenger.showSnackBar(SnackBar(
        content: Text((queued
                ? 'my_visits.plans.check_out.queued'
                : 'my_visits.plans.check_out.done')
            .tr)));
  }

  /// Runs once the visit is checked out — [queued] when that waits on the
  /// device for the server.
  final void Function(bool queued) onCheckedOut;

  @override
  State<PlanCheckOutButton> createState() => _PlanCheckOutButtonState();
}

class _PlanCheckOutButtonState extends State<PlanCheckOutButton> {
  /// Notes stay short on this step: a line or two about the visit. The
  /// server would take up to [PlanCheckOutRequest.maxNotesLength].
  static const notesLimit = 100;

  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => sl<PlanCheckOutCubit>(),
        child: BlocBuilder<PlanCheckOutCubit, PlanCheckOutState>(
          builder: _build,
        ),
      );

  Widget _build(BuildContext context, PlanCheckOutState state) {
    final scheme = Theme.of(context).colorScheme;
    final message = state.noLocation
        ? 'my_visits.plans.check_out.error.no_fix'.tr
        : state.failure?.userMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _notes,
          enabled: !state.busy,
          minLines: 1,
          maxLines: 3,
          maxLength: notesLimit,
          // Done closes the keyboard; the button is right below.
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          // Scrolls the button into view with the field, not just the field.
          scrollPadding: EdgeInsets.only(bottom: context.rh(140)),
          decoration: InputDecoration(
            labelText: 'my_visits.plans.check_out.notes.label'.tr,
            hintText: 'my_visits.plans.check_out.notes.hint'.tr,
            alignLabelWithHint: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(context.rr(12))),
          ),
        ),
        SizedBox(height: context.rh(8)),
        CoachKeys.wrap(
          CoachKeys.visitComplete,
          child: FilledButton.icon(
            onPressed: state.busy ? null : () => _checkOut(context),
            style: FilledButton.styleFrom(
              // Big and full width: the one thing to tap on this screen.
              minimumSize: Size.fromHeight(context.rh(54)),
              padding: EdgeInsets.symmetric(vertical: context.rh(14)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.rr(12))),
            ),
            icon: state.busy
                ? SizedBox.square(
                    dimension: context.rr(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: scheme.onPrimary))
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              state.stage == PlanCheckOutStage.locating
                  ? 'my_visits.plans.check_out.locating'.tr
                  : 'my_visits.plans.check_out.complete'.tr,
              style: TextStyle(
                  fontSize: context.rsp(15), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (message != null) ...[
          SizedBox(height: context.rh(8)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.error,
              fontSize: context.rsp(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _checkOut(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<PlanCheckOutCubit>();
    final done = await cubit.checkOut(widget.planId, notes: _notes.text);
    if (done) widget.onCheckedOut(cubit.state.queued);
  }
}
