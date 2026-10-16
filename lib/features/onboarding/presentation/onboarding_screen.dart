import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/database/hive/app_preferences.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/features/onboarding/presentation/widgets/story_scenes/story_scenes.dart';

/// First-run onboarding: the four beats of a rep's day, one per page.
///
/// This is where the route → visit → quotation → confirmation story lives now.
/// It used to play automatically on the splash screen, which was the wrong
/// place twice over: it delayed every launch for people who had already seen
/// it, and it ran at a fixed speed nobody could follow or replay. Here the user
/// sets the pace, can go back, and can leave at any point.
///
/// Reached from language selection (so the copy is already in the user's
/// language) and completed exactly once — finishing *or* skipping flips
/// `isOnboardingComplete`, after which the splash routes straight to the shell.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _leaving = false;

  /// The four beats. Illustration builders take the scene's own 0–1 progress,
  /// so each page replays its animation when it becomes visible.
  late final List<_Step> _steps = [
    _Step(
      key: 'route',
      build: (t) => RouteScene(
        t: t,
        line: AppColors.primary,
        marker: AppColors.primary,
      ),
    ),
    _Step(
      key: 'visit',
      build: (t) => VisitScene(
        t: t,
        accent: AppColors.primary,
        success: AppColors.success,
      ),
    ),
    _Step(
      key: 'quotation',
      build: (t) => OrderScene(
        t: t,
        accent: AppColors.primary,
        success: AppColors.success,
      ),
    ),
    _Step(
      key: 'success',
      build: (t) => SuccessScene(t: t, success: AppColors.success),
    ),
  ];

  bool get _isLast => _index == _steps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _back() {
    if (_index == 0) return;
    _pages.previousPage(
        duration: AppDurations.page, curve: AppCurves.emphasized);
  }

  void _next() {
    if (_isLast) {
      // Deliberately not awaited: `_finish` guards re-entry with `_leaving`,
      // and a button handler that returns a Future here would only widen the
      // signature without changing behaviour.
      unawaited(_finish());
      return;
    }
    _pages.nextPage(duration: AppDurations.page, curve: AppCurves.emphasized);
  }

  /// Both "Skip" and "Get started" land here: the user has decided they are
  /// done with onboarding, and the only difference is how much of it they read.
  /// Marking it complete either way is what stops it reappearing on next
  /// launch — a skipped tour that comes back is a tour that gets skipped again,
  /// more irritably.
  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;

    await sl<AppPreferences>().setOnboardingComplete(value: true);
    if (!mounted) return;

    // Guest-first, carried over from the language screen this replaced as the
    // last step: nobody is forced through login here. A restored session lands
    // authenticated; everyone else enters the shell as a guest and is prompted
    // only when they reach a protected feature (see AuthGuard).
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is! AuthenticatedState) {
      authBloc.add(const AuthGuestRequested());
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Static.main, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ────────────────────────────────────────────────────────
            // Always present, including on the last page: hiding it there means
            // the one control the user has been relying on disappears at the
            // moment they are closest to done.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'onboarding.skip'.tr,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // ── Story ───────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _StepPage(
                  step: _steps[i],
                  // Only the visible page animates. Playing all four at once
                  // would burn frames on illustrations nobody is looking at.
                  active: i == _index,
                ),
              ),
            ),

            // ── Progress ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    curve: AppCurves.standard,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    // The active dot stretches rather than just recolouring —
                    // legible at a glance without relying on colour alone.
                    width: i == _index ? 22 : 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Back / Continue ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  // Back keeps its space on the first page instead of being
                  // removed, so Continue does not jump sideways between pages.
                  Opacity(
                    opacity: _index == 0 ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _index == 0,
                      child: TextButton(
                        onPressed: _back,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        child: Text(
                          'common.back'.tr,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _isLast
                          ? 'onboarding.get_started'.tr
                          : 'common.continue'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({required this.key, required this.build});

  /// Localisation key segment: `onboarding.steps.<key>.title` / `.body`.
  final String key;
  final Widget Function(double t) build;
}

/// One onboarding page: illustration above, copy below.
///
/// The illustration replays whenever the page becomes active — an onboarding
/// step the user paged back to should show its animation again, not a frozen
/// final frame.
class _StepPage extends StatefulWidget {
  const _StepPage({required this.step, required this.active});

  final _Step step;
  final bool active;

  @override
  State<_StepPage> createState() => _StepPageState();
}

class _StepPageState extends State<_StepPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play;

  /// Scenes fade themselves out past ~0.86 of their window (see `SceneShell`),
  /// so the animation stops at its visual peak and stays there. Running to 1.0
  /// would leave every onboarding page blank once its animation finished.
  static const double _peak = 0.80;

  @override
  void initState() {
    super.initState();
    _play = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
      upperBound: _peak,
    );
    if (widget.active) _play.forward();
  }

  @override
  void didUpdateWidget(covariant _StepPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _play
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: AnimatedBuilder(
              animation: _play,
              // Reduce-motion gets the finished illustration, not a blank box:
              // the picture carries the meaning, only the movement is optional.
              builder: (context, _) =>
                  widget.step.build(reduceMotion ? _peak : _play.value),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'onboarding.steps.${widget.step.key}.title'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'onboarding.steps.${widget.step.key}.body'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
