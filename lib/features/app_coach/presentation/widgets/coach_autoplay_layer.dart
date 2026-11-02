import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_status.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_autopilot.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_route_tracker.dart';

/// "Watch demo": performs the running practice lesson step by step, the way
/// a rep would, while the guide narrates.
///
/// For each step it waits for the step's target to be on screen, brings it
/// into view, shows a finger on it, then taps it (or runs the screen's
/// [CoachDriver]). It answers the dialogs a step opens through their
/// [CoachAutopilot.confirmAnchor] button, and moves on only when the app
/// itself reports the result — exactly the events a rep's own taps produce.
///
/// It never retries a failure and never guesses: when a step fails, or its
/// target does not appear, or nothing happens after the tap, it stops and
/// hands control to the rep with a reason. A system prompt (location
/// permission, the camera) belongs to the OS; while one is up the app is
/// inactive, and autoplay waits instead of timing out.
class CoachAutoplayLayer extends StatefulWidget {
  const CoachAutoplayLayer({
    super.key,
    required this.bloc,
    this.tracker,
    this.timing = const CoachAutoplayTiming(),
  });

  final AppCoachBloc bloc;
  final CoachRouteTracker? tracker;
  final CoachAutoplayTiming timing;

  @override
  State<CoachAutoplayLayer> createState() => _CoachAutoplayLayerState();
}

/// Pacing, so the narration can be read. Tests shorten it.
@immutable
class CoachAutoplayTiming {
  const CoachAutoplayTiming({
    // These pauses are long enough for the guide's finger cue to register,
    // without making every action feel like it is waiting on an animation.
    this.beforeTap = const Duration(milliseconds: 250),
    this.fingerHold = const Duration(milliseconds: 300),
    this.findTarget = const Duration(seconds: 8),
    this.awaitResult = const Duration(seconds: 12),
    this.poll = const Duration(milliseconds: 150),
    this.readPerChar = const Duration(milliseconds: 35),
    this.readMin = const Duration(milliseconds: 1200),
    this.readMax = const Duration(milliseconds: 3500),
  });

  final Duration beforeTap;
  final Duration fingerHold;
  final Duration findTarget;
  final Duration awaitResult;
  final Duration poll;
  final Duration readPerChar;
  final Duration readMin;
  final Duration readMax;
}

class _CoachAutoplayLayerState extends State<CoachAutoplayLayer>
    with WidgetsBindingObserver {
  StreamSubscription<AppCoachState>? _sub;
  CoachAnchorRegistry? _registry;
  int _run = 0;
  String? _runningKey;

  /// Where the finger is. Kept after it fades out, so the next target is
  /// reached by gliding from the last one rather than popping up.
  Offset? _finger;
  bool _fingerShown = false;
  bool _appActive = true;

  void _showFinger(Offset at) => setState(() {
        _finger = at;
        _fingerShown = true;
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = widget.bloc.stream.listen(_onState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onState(widget.bloc.state);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = CoachAnchorScope.maybeOf(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _run++;
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onState(AppCoachState state) {
    final step = state.currentStep;
    final active =
        state.autoplay && state.status == CoachStatus.running && step != null;
    final key = active ? '${state.module?.id}/${step.id}' : null;
    if (key == _runningKey) return;
    _runningKey = key;
    final run = ++_run;
    if (_fingerShown && mounted) setState(() => _fingerShown = false);
    if (key != null) _perform(run, step!);
  }

  bool _stale(int run) => !mounted || run != _run;

  Future<bool> _sleep(int run, Duration d) async {
    await Future<void>.delayed(d);
    return !_stale(run);
  }

  Duration _readTime(CoachStep step) {
    final t = widget.timing;
    final chars = step.messageKey.tr.length + step.titleKey.tr.length;
    final ms = t.readMin.inMilliseconds + chars * t.readPerChar.inMilliseconds;
    return Duration(
        milliseconds:
            ms.clamp(t.readMin.inMilliseconds, t.readMax.inMilliseconds));
  }

  Future<void> _perform(int run, CoachStep step) async {
    final t = widget.timing;

    if (step.isInformational) {
      if (!await _sleep(run, _readTime(step))) return;
      widget.bloc.add(const CoachCtaPressed());
      return;
    }

    final id = step.targetKeyId;
    if (id == null) return _handOver(run);
    if (!await _sleep(run, t.beforeTap)) return;

    // Find the target: it may be on a screen still being pushed, or in a
    // list still loading.
    final rect = await _waitFor(run, t.findTarget, () => _rectOf(id));
    if (rect == null) return _handOver(run);

    final ctx = _registry?.contextFor(id);
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx,
          alignment: 0.4, duration: const Duration(milliseconds: 220));
      if (!await _sleep(run, const Duration(milliseconds: 80))) return;
    }
    final target = _rectOf(id) ?? rect;

    _showFinger(target.center);
    if (!await _sleep(run, t.fingerHold)) return;

    final driver = CoachAutopilot.driverFor(id);
    if (driver != null) {
      await driver();
    } else {
      await CoachAutopilot.tapAt(target.center);
    }
    if (_stale(run)) return;
    setState(() => _fingerShown = false);

    // Wait for the app to report the result, answering any dialog the tap
    // opened. A new step (or autoplay switching off) ends this run first.
    var waited = Duration.zero;
    while (!_stale(run)) {
      if (!await _sleep(run, t.poll)) return;
      if (!_appActive) continue; // an OS prompt is up: wait for the rep
      await _answerDialog(run);
      waited += t.poll;
      if (waited >= t.awaitResult) return _handOver(run);
    }
  }

  Rect? _rectOf(String id) => _registry?.rectFor(id);

  Future<Rect?> _waitFor(
      int run, Duration timeout, Rect? Function() find) async {
    var waited = Duration.zero;
    while (!_stale(run)) {
      final r = find();
      if (r != null) return r;
      await _answerDialog(run);
      if (!await _sleep(run, widget.timing.poll)) return null;
      if (_appActive) waited += widget.timing.poll;
      if (waited >= timeout) return null;
    }
    return null;
  }

  /// Presses a dialog's autoplay button, if a dialog with one is open.
  Future<void> _answerDialog(int run) async {
    final popup = widget.tracker?.value.popupOpen ?? false;
    if (!popup) return;
    final rect = _rectOf(CoachAutopilot.confirmAnchor);
    if (rect == null) return;
    _showFinger(rect.center);
    if (!await _sleep(run, widget.timing.fingerHold)) return;
    await CoachAutopilot.tapAt(rect.center);
    if (!_stale(run)) setState(() => _fingerShown = false);
    await _sleep(run, const Duration(milliseconds: 500));
  }

  void _handOver(int run) {
    if (_stale(run)) return;
    setState(() => _fingerShown = false);
    widget.bloc.add(
        const CoachAutoplayChanged(false, reasonKey: 'coach.autoplay.stuck'));
  }

  @override
  Widget build(BuildContext context) {
    final finger = _finger;
    return IgnorePointer(
      child: Stack(
        children: [
          if (finger != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: finger.dx - 22,
              top: finger.dy - 22,
              child: AnimatedOpacity(
                opacity: _fingerShown ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: const _Finger(),
              ),
            ),
        ],
      ),
    );
  }
}

/// The demo's finger: where autoplay is about to tap.
class _Finger extends StatelessWidget {
  const _Finger();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.4, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.28),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(Icons.touch_app_rounded, color: color, size: 22),
      ),
    );
  }
}

/// Wires a [CoachAutoplayLayer] to the [AppCoachBloc] in context.
class CoachAutoplayScope extends StatelessWidget {
  const CoachAutoplayScope({super.key, this.tracker});

  final CoachRouteTracker? tracker;

  @override
  Widget build(BuildContext context) => CoachAutoplayLayer(
        bloc: context.read<AppCoachBloc>(),
        tracker: tracker,
      );
}
