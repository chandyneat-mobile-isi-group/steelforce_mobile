import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/presentation/bloc/add_depot_bloc.dart';

/// Turns the registration wizard's state changes into App Coach actions.
///
/// Reports only what the bloc confirmed: a step reached after validation, a
/// Next or Submit validation refused, a submit that succeeded or failed. It
/// never changes what the wizard does — outside a lesson every report is a
/// no-op ([AppCoach.notify]).
///
/// Kept apart from the widget so the rules can be tested on plain states.
class DepotWizardCoachTracker {
  /// Set when the rep taps Next or Submit; cleared by the first answer.
  bool _advanceRequested = false;

  /// The rep asked to move on. The next state tells whether validation let
  /// them.
  void advanceRequested() => _advanceRequested = true;

  /// The actions [curr] confirms, in the order they happened.
  ///
  /// [trackSteps] is false where the layout drives the bloc's step itself in
  /// jumps that do not map onto one lesson step each (the tablet stages) —
  /// that layout reports its own advances through [stepsReached].
  List<CoachAction> onState(
    AddDepotState prev,
    AddDepotState curr, {
    bool trackSteps = true,
  }) {
    final actions = <CoachAction>[];

    if (curr.status != prev.status) {
      if (curr.status == AddDepotStatus.success) {
        _advanceRequested = false;
        return [CoachAction.createDepotSucceeded];
      }
      if (curr.status == AddDepotStatus.failure) {
        _advanceRequested = false;
        return [CoachAction.createDepotFailed];
      }
      if (curr.status == AddDepotStatus.submitting) {
        // Validation passed; the outcome arrives as success or failure.
        _advanceRequested = false;
        return const [];
      }
    }

    final forward = curr.currentStep.index > prev.currentStep.index;
    if (trackSteps && forward && curr.errors.isEmpty) {
      for (var i = prev.currentStep.index + 1;
          i <= curr.currentStep.index;
          i++) {
        final action = reachedStep(BpFormStep.values[i]);
        if (action != null) actions.add(action);
      }
      _advanceRequested = false;
      return actions;
    }

    if (_advanceRequested && curr.errors.isNotEmpty) {
      _advanceRequested = false;
      actions.add(CoachAction.depotFormInvalid);
    }
    return actions;
  }

  /// A layout that moves through several steps at once (the tablet stages)
  /// reports here that validation let the rep through to [steps].
  List<CoachAction> stepsReached(Iterable<BpFormStep> steps) {
    _advanceRequested = false;
    return [
      for (final step in steps)
        if (reachedStep(step) case final action?) action,
    ];
  }

  /// The action for arriving at [step], or null for the first step.
  static CoachAction? reachedStep(BpFormStep step) => switch (step) {
        BpFormStep.identity => null,
        BpFormStep.address => CoachAction.depotFormAddress,
        BpFormStep.contact => CoachAction.depotFormContact,
        BpFormStep.salesTerms => CoachAction.depotFormSalesTerms,
        // No lesson stops on the survey; the coach picks up again at photos.
        BpFormStep.salesPerformance => null,
        BpFormStep.documents => CoachAction.depotFormDocuments,
        BpFormStep.review => CoachAction.depotFormReview,
      };
}

/// Reports [tracker]'s actions for every [AddDepotBloc] state change below it.
///
/// Adds no layout: it is a [BlocListener] around [child].
class DepotWizardCoachListener extends StatelessWidget {
  const DepotWizardCoachListener({
    super.key,
    required this.tracker,
    required this.trackSteps,
    required this.child,
  });

  final DepotWizardCoachTracker tracker;

  /// See [DepotWizardCoachTracker.onState].
  final bool Function() trackSteps;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `listenWhen` sees both states and `listener` only the new one, so the
    // actions are worked out in the first and reported by the second. The
    // two run back to back for the same change.
    var pending = const <CoachAction>[];
    return BlocListener<AddDepotBloc, AddDepotState>(
      listenWhen: (prev, curr) {
        pending = tracker.onState(prev, curr, trackSteps: trackSteps());
        return pending.isNotEmpty;
      },
      listener: (_, __) {
        final actions = pending;
        pending = const [];
        actions.forEach(AppCoach.notify);
      },
      child: child,
    );
  }
}
