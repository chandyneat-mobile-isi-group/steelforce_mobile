import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/core/database/hive/app_preferences.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/splash/presentation/animation/logo_reveal.dart';
import 'package:steelforce/features/splash/presentation/animation/splash_timeline.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/shared/animations/steel_particle_field.dart';

/// The SteelForce launch screen: a steel field gathering into the brand mark.
///
/// ## Boot decision (unchanged)
///
/// Still the single decision point for the boot flow:
///
///   • onboarding **not** complete -> language selection, which now leads into
///     the onboarding story
///   • onboarding complete         -> main shell (auth resolves in the
///                                     background; guests and signed-in users
///                                     both land on the shell)
///
/// ## Why this is short now
///
/// This screen used to carry a ten-second, seven-scene story of a rep's day.
/// That story was worth telling, but not on every launch — so it moved to
/// onboarding, where it is shown once, at the only moment the user has a reason
/// to watch it, and where they can page through it at their own speed. What is
/// left here is under three seconds and still skippable.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _story;

  /// Navigation must happen exactly once: the controller finishing, a tap, and
  /// the reduce-motion path can all race to it.
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _story = AnimationController(vsync: this, duration: SplashTimeline.total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _leave();
      });
    // Started from the first frame so the first paint is frame zero of the
    // animation rather than a frame of its finished state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _story.forward();
    });
  }

  @override
  void dispose() {
    _story.dispose();
    super.dispose();
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    // A restored session with a temporary password still in force must be
    // finished before the shell.
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthenticatedState && auth.passwordChangeRequired) {
      Navigator.of(context)
          .pushReplacementNamed(Static.changeTemporaryPassword);
      return;
    }
    final onboarded = sl<AppPreferences>().isOnboardingComplete;
    Navigator.of(context).pushReplacementNamed(
      onboarded ? Static.main : Static.chooseLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Honour reduce-motion: hold the brand briefly, then go. The animation is
    // decoration; the destination is the product.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _story.stop();
      Future.delayed(const Duration(milliseconds: 600), _leave);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        // Tap anywhere to skip. Nothing here is worth making someone wait for.
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: _story,
          builder: (context, _) {
            final p = reduceMotion ? 0.80 : _story.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Near-white, with the faintest cool wash so the screen is not
                // a dead flat field behind the motion.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(
                            Colors.white, AppColors.primary, 0.02 + 0.02 * p)!,
                        Colors.white,
                        Color.lerp(Colors.white, AppColors.slate, 0.035)!,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),

                SteelParticleField(
                  progress: p,
                  steel: AppColors.slate,
                  highlight: AppColors.primary,
                  convergeFrom: SplashTimeline.convergeFrom,
                ),

                Center(
                  child: LogoReveal(
                    t: SplashTimeline.logo.transform(p),
                    settle: SplashTimeline.handoff.transform(p),
                    highlight: AppColors.primary,
                  ),
                ),

                // Washes out to white so the splash dissolves into the app
                // rather than cutting to it.
                IgnorePointer(
                  child: Opacity(
                    opacity: 0.55 * SplashTimeline.handoff.transform(p),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
