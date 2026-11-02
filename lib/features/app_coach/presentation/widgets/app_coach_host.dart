import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_status.dart';
import 'package:steelforce/features/app_coach/domain/repositories/coach_repository.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_route_tracker.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/assistant_overlay.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/coach_autoplay_layer.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/coach_lessons_sheet.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/floating_assistant_button.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/practice_frame.dart';
import 'package:steelforce/features/shell/presentation/navigation/shell_tab_controller.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';

/// Mounts the coach above the app's Navigator.
///
/// Wraps `MaterialApp.builder`'s child: provides the app-wide
/// [CoachAnchorScope] (so anchors on *any* route — a pushed depot form, a
/// visit's check-in — can be found) and draws [AppCoachHost] over every
/// route. It brings its own [Overlay], because `builder` sits outside the
/// Navigator's and the bubble's tooltips need one.
class CoachRoot extends StatefulWidget {
  const CoachRoot({super.key, required this.child});

  final Widget child;

  @override
  State<CoachRoot> createState() => _CoachRootState();
}

class _CoachRootState extends State<CoachRoot> {
  final CoachAnchorRegistry _registry = CoachAnchorRegistry();
  late final OverlayEntry _entry =
      OverlayEntry(builder: (_) => const AppCoachHost());

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoachAnchorScope(
      registry: _registry,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned.fill(child: Overlay(initialEntries: [_entry])),
        ],
      ),
    );
  }
}

/// The coach layer itself.
///
/// Signed-in only. The coach walks a rep through *their* work — a guest has
/// none, and the guest landing has its own call to action that the floating
/// assistant would sit on top of. [AppCoachBloc] is an app-wide singleton
/// whose state outlives a sign-out, so this host hides the whole layer
/// whenever the session is not signed in, and starts the coach when a sign-in
/// lands.
///
/// What it shows:
///
/// * **The tour** (blocking steps) — only while the shell is the page on top.
///   Sitting above the Navigator, it would otherwise dim screens the tour
///   knows nothing about.
/// * **A lesson** (non-blocking steps) — on whatever screen the rep is on;
///   folded to a [LessonChip] while a dialog, sheet or the keyboard is up, so
///   it never covers the control the rep needs.
/// * **Practice** — the [PracticeFrame] around every screen for as long as a
///   practice run lasts, paused or not.
/// * **Idle** — the floating assistant on the Home tab, which opens the
///   lessons; the paused tour's mascot in its place while the tour is paused.
class AppCoachHost extends StatefulWidget {
  const AppCoachHost({
    super.key,
    this.session,
    this.tracker,
    this.practice,
  });

  /// Defaults to the app's [SessionManager]; injectable for tests.
  final SessionManager? session;
  final CoachRouteTracker? tracker;
  final PracticeSession? practice;

  @override
  State<AppCoachHost> createState() => _AppCoachHostState();
}

class _AppCoachHostState extends State<AppCoachHost> {
  final AppCoachBloc _bloc = sl<AppCoachBloc>();
  final ShellTabController _tabs = sl<ShellTabController>();
  late final SessionManager _session = widget.session ?? sl<SessionManager>();
  late final CoachRouteTracker? _tracker = widget.tracker ??
      (sl.isRegistered<CoachRouteTracker>() ? sl<CoachRouteTracker>() : null);
  late final PracticeSession? _practice = widget.practice ??
      (sl.isRegistered<PracticeSession>() ? sl<PracticeSession>() : null);
  StreamSubscription<Object?>? _sessionSub;
  late bool _signedIn = _session.isAuthenticated;
  String? _shownStepKey;
  bool _minimized = false;
  bool _wasPractice = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _tracker?.addListener(_rebuild);
    _practice?.addListener(_rebuild);
    _sessionSub = _session.changes.listen((_) => _onSessionChanged());
    AppCoach.attachLessonsOpener(_openLessons);
    if (_signedIn) _bloc.add(const CoachStarted());
  }

  @override
  void dispose() {
    AppCoach.attachLessonsOpener(null);
    _sessionSub?.cancel();
    _tabs.removeListener(_onTabChanged);
    _tracker?.removeListener(_rebuild);
    _practice?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
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

  /// Back to the shell's Home, closing every screen above it.
  void _returnToShell() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (_tabs.value != ShellTab.home) _tabs.goTo(ShellTab.home);
  }

  void _onState(AppCoachState state) {
    // A practice run ended — finished, skipped, exited or replaced. Close
    // the screens it opened: they were built over demo data.
    if (_wasPractice && !state.inPractice) _returnToShell();

    final step = state.currentStep;
    final key = step == null ? null : '${state.module?.id}/${step.id}';
    final startedLesson = state.status == CoachStatus.running &&
        state.index == 0 &&
        key != _shownStepKey;
    // A lesson starts from the Home screen, wherever it was opened from.
    if (startedLesson && (state.module?.practice ?? false)) _returnToShell();
    _wasPractice = state.inPractice;

    if (step == null || key == _shownStepKey) return;
    _shownStepKey = key;
    _minimized = false;

    if (step.autoNavigateHome && _tabs.value != ShellTab.home) {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) _tabs.goTo(ShellTab.home);
      });
    }

    final id = step.targetKeyId;
    // Autoplay scrolls its own target into view just before it taps; a
    // second scroll from here would fight it and jerk the page.
    if (id == null || state.autoplay) return;
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

  /// True while one of the coach's own sheets is open.
  ///
  /// This layer sits *above* the Navigator, so a sheet it opens appears
  /// underneath the practice chip and the assistant — both stay tappable
  /// while it is up. Without this guard every extra tap stacked another
  /// sheet on top of the first.
  bool _sheetOpen = false;

  /// Something modal is up — one of ours, or the app's own dialog/sheet —
  /// so the coach's buttons must not open anything more.
  bool get _modalUp => _sheetOpen || (_tracker?.value.popupOpen ?? false);

  Future<void> _showSheet(Future<void> Function(BuildContext nav) open) async {
    final nav = navigatorKey.currentContext;
    if (nav == null || _modalUp) return;
    setState(() => _sheetOpen = true);
    try {
      await open(nav);
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  void _openLessons() => _showSheet((nav) => CoachLessonsSheet.show(
        nav,
        modules: sl<CoachRepository>().getModules(),
        state: _bloc.state,
        onStart: (id) => _bloc.add(CoachModuleStarted(id)),
        onWatch: (id) => _bloc.add(CoachModuleStarted(id, autoplay: true)),
        onResume: () => _bloc.add(const CoachResumed()),
      ));

  void _openPracticeMenu() => _showSheet(_practiceMenu);

  Future<void> _practiceMenu(BuildContext nav) {
    final state = _bloc.state;
    final paused = state.status == CoachStatus.paused;
    return showModalBottomSheet<void>(
      context: nav,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) {
        void act(VoidCallback f) {
          Navigator.of(sheet).pop();
          f();
        }

        // Scrolls rather than clips: a sheet is capped at 9/16 of the screen,
        // and six rows in Khmer or at a large text scale do not fit.
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text('coach.practice.menu_title'.tr),
                  subtitle: Text('coach.practice.menu_body'.tr),
                ),
                ListTile(
                  leading: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  title: Text(paused
                      ? 'coach.practice.resume'.tr
                      : 'coach.practice.pause'.tr),
                  onTap: () => act(() => _bloc.add(
                      paused ? const CoachResumed() : const CoachPaused())),
                ),
                if (!paused)
                  ListTile(
                    leading: Icon(state.autoplay
                        ? Icons.pan_tool_alt_outlined
                        : Icons.smart_display_outlined),
                    title: Text(state.autoplay
                        ? 'coach.autoplay.take_over'.tr
                        : 'coach.autoplay.resume'.tr),
                    onTap: () => act(
                        () => _bloc.add(CoachAutoplayChanged(!state.autoplay))),
                  ),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: Text('coach.practice.restart'.tr),
                  onTap: () => act(() {
                    final id = state.module?.id;
                    if (id != null) _bloc.add(CoachModuleStarted(id));
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text('coach.practice.all_lessons'.tr),
                  onTap: () => act(_openLessons),
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text('coach.practice.exit'.tr),
                  onTap: () => act(() => _bloc.add(const CoachSkipped())),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) return const SizedBox.shrink();

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return BlocProvider<AppCoachBloc>.value(
      value: _bloc,
      child: BlocConsumer<AppCoachBloc, AppCoachState>(
        listener: (_, state) => _onState(state),
        buildWhen: (a, b) =>
            a.status != b.status ||
            a.index != b.index ||
            a.module?.id != b.module?.id ||
            a.failureKey != b.failureKey ||
            a.completedStepIds.length != b.completedStepIds.length ||
            a.completedModuleIds.length != b.completedModuleIds.length ||
            a.isVisible != b.isVisible ||
            a.mascotHidden != b.mascotHidden ||
            a.autoplay != b.autoplay,
        builder: (context, state) {
          final practice = state.inPractice && (_practice?.isActive ?? true);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: _buildLayer(state, reduceMotion)),
              // "Watch demo": taps on the app below, draws only its finger.
              if (state.inPractice)
                Positioned.fill(
                  child: CoachAutoplayLayer(bloc: _bloc, tracker: _tracker),
                ),
              if (practice)
                Positioned.fill(
                  child: PracticeFrame(
                    lessonTitle: state.module?.titleKey.tr ?? '',
                    paused: state.status == CoachStatus.paused,
                    // Inert while a sheet or dialog is up: one menu at a
                    // time, and never over a dialog the rep must answer.
                    onTap: _modalUp ? null : _openPracticeMenu,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLayer(AppCoachState state, bool reduceMotion) {
    final route = _tracker?.value ?? const CoachRouteInfo(pageDepth: 1);
    final onHome = route.shellOnTop && _tabs.value == ShellTab.home;
    final step = state.currentStep;

    final Key key;
    final Widget child;

    if (state.status == CoachStatus.paused) {
      // A paused practice lesson is resumed from the practice chip; the
      // mascot is the paused *tour*'s way back.
      if (state.inPractice || !onHome || state.mascotHidden) {
        key = const ValueKey('coach-empty');
        child = const SizedBox.shrink();
      } else {
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
      }
    } else if (state.status == CoachStatus.completed) {
      // Nothing running: the assistant that opens the lessons, Home only —
      // unless the rep hid it; the lessons are on Profile then.
      if (onHome && !state.mascotHidden) {
        key = const ValueKey('coach-assistant');
        child = FloatingAssistantButton(
          onResume: () {
            if (!_modalUp) _openLessons();
          },
          semanticsLabelKey: 'coach.lessons.open_hint',
        );
      } else {
        key = const ValueKey('coach-empty');
        child = const SizedBox.shrink();
      }
    } else if (!state.isVisible || step == null) {
      key = const ValueKey('coach-empty');
      child = const SizedBox.shrink();
    } else if (step.blocking) {
      // The tour: only over the shell.
      if (route.shellOnTop) {
        key = const ValueKey('coach-overlay');
        child = AssistantOverlay(
          step: step,
          stepNumber: step.order,
          totalSteps: state.steps.length,
          progress: state.progress,
          reduceMotion: reduceMotion,
          onCta: () => _bloc.add(const CoachCtaPressed()),
          onSkip: () => _bloc
            ..add(const CoachSkipped())
            ..add(const CoachMascotHidden()),
          onClose: () => _bloc
            ..add(const CoachPaused())
            ..add(const CoachMascotHidden()),
        );
      } else {
        key = const ValueKey('coach-empty');
        child = const SizedBox.shrink();
      }
    } else {
      // A lesson step: the guide, or the chip when something is in the way.
      final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
      final folded = _minimized || route.popupOpen || keyboard;
      if (folded) {
        key = const ValueKey('coach-chip');
        child = Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 34),
              child: LessonChip(
                title: step.titleKey.tr,
                stepNumber: step.order,
                totalSteps: state.steps.length,
                hasFailure: state.failureKey != null,
                // While a dialog is open the chip only informs: the dialog
                // is what the rep must answer.
                onExpand: route.popupOpen
                    ? null
                    : () => setState(() => _minimized = false),
              ),
            ),
          ),
        );
      } else {
        key = ValueKey('coach-guide-${state.module?.id}');
        child = AssistantOverlay(
          step: step,
          stepNumber: step.order,
          totalSteps: state.steps.length,
          progress: state.progress,
          reduceMotion: reduceMotion,
          lessonTitleKey: state.module?.titleKey,
          failureKey: state.failureKey,
          onCta: () => _bloc.add(const CoachCtaPressed()),
          onSkip: () => _bloc
            ..add(const CoachSkipped())
            ..add(const CoachMascotHidden()),
          onClose: () => _bloc
            ..add(const CoachPaused())
            ..add(const CoachMascotHidden()),
          onMinimize: () => setState(() => _minimized = true),
          autoplay: (state.module?.practice ?? false) ? state.autoplay : null,
          onToggleAutoplay: () =>
              _bloc.add(CoachAutoplayChanged(!state.autoplay)),
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
      // This switcher crossfades between very differently sized children: an
      // empty `SizedBox.shrink()` (0×0), a 120×120 `Align`ed Lottie bubble
      // when paused, and the full-screen `AssistantOverlay` when running.
      // `AnimatedSwitcher.defaultLayoutBuilder` stacks the outgoing and
      // incoming child as plain (non-`Positioned`) `Stack` children, so
      // during a crossfade their sizes diverge wildly and the `Stack` around
      // them, plus everything below it, is asked to relayout every frame of
      // the transition — a real layout storm that surfaced as
      // `!semantics.parentDataDirty` / `RenderBox was not laid out`
      // assertions after every `tutorial_resume`.
      //
      // Constraining every child to fill the available space, exactly as the
      // `AnimatedSwitcher` docs recommend for children of different sizes,
      // removes the size jump without changing how anything looks: each child
      // already positions its own visible content.
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
