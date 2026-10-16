import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_status.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/assistant_overlay.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

/// Mounts the coach layer over the app shell.
///
/// Signed-in only. The coach walks a rep through *their* work — a guest has
/// none, and the guest landing has its own call to action that the floating
/// assistant would sit on top of. [AppCoachBloc] is an app-wide singleton
/// whose state outlives a sign-out, so this host hides the whole layer
/// (overlay and the paused mascot alike) whenever the session is not
/// signed in, and starts the coach when a sign-in lands.
///
/// The paused assistant (the floating [CoachMascot]) shows on the Home tab
/// only — elsewhere it would sit on the screen's own content and actions
/// (the Visits list, the cart). A *running* tutorial is not limited: some of
/// its steps ask the rep to open Visits, Depots or Orders and carry on there.
class AppCoachHost extends StatefulWidget {
  const AppCoachHost({super.key, this.session});

  /// Defaults to the app's [SessionManager]; injectable for tests.
  final SessionManager? session;

  @override
  State<AppCoachHost> createState() => _AppCoachHostState();
}

class _AppCoachHostState extends State<AppCoachHost> {
  final AppCoachBloc _bloc = sl<AppCoachBloc>();
  final ShellTabController _tabs = sl<ShellTabController>();
  late final SessionManager _session = widget.session ?? sl<SessionManager>();
  StreamSubscription<Object?>? _sessionSub;
  late bool _signedIn = _session.isAuthenticated;
  String? _shownStepId;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _sessionSub = _session.changes.listen((_) => _onSessionChanged());
    if (_signedIn) _bloc.add(const CoachStarted());
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _tabs.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final signedIn = _session.isAuthenticated;
    if (signedIn == _signedIn || !mounted) return;
    setState(() => _signedIn = signedIn);
    if (signedIn) _bloc.add(const CoachStarted());
  }

  void _onTabChanged() {
    if (!_signedIn) return;
    // Rebuild so the paused bubble follows the Home tab.
    if (mounted) setState(() {});
    const map = <int, CoachAction>{
      ShellTab.home: CoachAction.openHome,
      ShellTab.depots: CoachAction.openDepots,
      ShellTab.myVisits: CoachAction.openMyVisits,
      ShellTab.orders: CoachAction.openOrders,
    };
    final action = map[_tabs.value];
    if (action != null) _bloc.add(CoachActionTriggered(action));
  }

  void _onStepShown(AppCoachState state) {
    final step = state.currentStep;
    if (step == null || step.id == _shownStepId) return;
    _shownStepId = step.id;

    if (step.autoNavigateHome && _tabs.value != ShellTab.home) {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) _tabs.goTo(ShellTab.home);
      });
    }

    final id = step.targetKeyId;
    if (id == null) return;
    final registry = CoachAnchorScope.maybeOf(context);
    if (registry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = registry.contextFor(id);
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.35,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) return const SizedBox.shrink();

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return BlocProvider<AppCoachBloc>.value(
      value: _bloc,
      child: BlocConsumer<AppCoachBloc, AppCoachState>(
        listener: (_, state) => _onStepShown(state),
        buildWhen: (a, b) =>
            a.status != b.status ||
            a.index != b.index ||
            a.completedStepIds.length != b.completedStepIds.length ||
            a.isVisible != b.isVisible,
        builder: (context, state) {
          // Immediately unmount layer if completed or invisible (and not paused)
          if (state.status == CoachStatus.completed ||
              (!state.isVisible && state.status != CoachStatus.paused)) {
            return const SizedBox.shrink();
          }

          return _buildLayer(state, reduceMotion);
        },
      ),
    );
  }

  Widget _buildLayer(AppCoachState state, bool reduceMotion) {
    final Key key;
    final Widget child;

    if (state.status == CoachStatus.paused && _tabs.value != ShellTab.home) {
      key = const ValueKey('coach-empty');
      child = const SizedBox.shrink();
    } else if (state.status == CoachStatus.paused) {
      key = const ValueKey('coach-paused');
      child = Align(
        alignment: Alignment.bottomRight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
            child: Semantics(
              button: true,
              label: 'coach.resume_hint'.tr,
              child: GestureDetector(
                onTap: () => _bloc.add(const CoachResumed()),
                child: CoachMascot(size: 120, animate: !reduceMotion),
              ),
            ),
          ),
        ),
      );
    } else {
      final step = state.currentStep;
      if (!state.isVisible || step == null) {
        key = const ValueKey('coach-empty');
        child = const SizedBox.shrink();
      } else {
        key = const ValueKey('coach-overlay');
        child = AssistantOverlay(
          step: step,
          stepNumber: step.order,
          totalSteps: state.steps.length,
          progress: state.progress,
          reduceMotion: reduceMotion,
          onCta: () => _bloc.add(const CoachCtaPressed()),
          onSkip: () => _bloc.add(const CoachSkipped()),
          onClose: () => _bloc.add(const CoachPaused()),
        );
      }
    }

    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Explicit `layoutBuilder`, not the default.
      //
      // This switcher crossfades between three very differently sized
      // children: an empty `SizedBox.shrink()` (0×0), a 120×120 `Align`ed
      // Lottie bubble when paused, and the full-screen `AssistantOverlay`
      // when running. `AnimatedSwitcher.defaultLayoutBuilder` stacks the
      // outgoing and incoming child as plain (non-`Positioned`) `Stack`
      // children, so during a crossfade — both mounted and laid out at once —
      // their sizes diverge wildly and the `Stack` around them, plus
      // everything below it, is asked to relayout every frame of the 220ms
      // transition.
      //
      // The correlation was exact: `[coach] tutorial_resume` (the paused →
      // running transition, exercising precisely this size jump) preceded
      // every occurrence of a render-pipeline assertion flood
      // (`!semantics.parentDataDirty`, `RenderBox was not laid out`) logged
      // during this work. Both assertions are debug-only — `assert()` is
      // compiled out of release — so this was not corrupting a shipped build,
      // but the size-mismatched crossfade generating a real layout storm on
      // every transition is a genuine defect independent of that.
      //
      // Constraining every child to fill the available space, exactly as the
      // `AnimatedSwitcher` docs recommend for children of different sizes,
      // removes the size jump without changing how anything looks: each child
      // already positions its own visible content (the Lottie bubble via its
      // own `Align`, the overlay via its own scrim) inside the space it is
      // given.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          for (final child in previousChildren) Positioned.fill(child: child),
          if (currentChild != null) Positioned.fill(child: currentChild),
        ],
      ),
      child: KeyedSubtree(key: key, child: child),
    );
  }
}
