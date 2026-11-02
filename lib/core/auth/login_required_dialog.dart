import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// The outcome of a [LoginRequiredDialog].
enum LoginPromptResult {
  /// The user chose to sign in — the caller has been routed to login.
  login,

  /// The user dismissed the prompt (tapped "Later", scrimmed, or backed out)
  /// and stays where they were, still browsing as a guest.
  dismissed,
}

/// A premium, brand-styled "Login Required" prompt for guest users who reach a
/// protected feature.
///
/// Features the SteelForce [BrandWallpaperBackground] with fine brand zigzags,
/// an elevated floating lock badge, feature preview chips, and responsive
/// layout for phone and tablet.
class LoginRequiredDialog extends StatelessWidget {
  const LoginRequiredDialog({super.key});

  /// Shows the dialog and resolves once dismissed. On "Login Now" it routes to
  /// the login screen and resolves with [LoginPromptResult.login]; otherwise
  /// [LoginPromptResult.dismissed].
  static Future<LoginPromptResult> show(BuildContext context) async {
    final result = await showGeneralDialog<LoginPromptResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'auth.login_required_title'.tr,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const LoginRequiredDialog(),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? LoginPromptResult.dismissed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final c = context.appColors;

    final boxScale =
        context.responsive(compact: 1.0, medium: 1.20, expanded: 1.30);
    final typeScale =
        context.responsive(compact: 1.0, medium: 1.25, expanded: 1.35);
    final maxMeasure = context.responsive(
      compact: 380.0,
      medium: 420.0,
      expanded: 440.0,
    );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 20 * boxScale,
          vertical: 24 * boxScale,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxMeasure),
          child: Material(
            color: c.card,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(28 * boxScale),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branded header banner using SteelForce wallpaper pattern
                SizedBox(
                  height: 116 * boxScale,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: BrandWallpaperBackground(
                          style: BrandWallpaperStyle.vivid,
                        ),
                      ),
                      // Top-right close button
                      Positioned(
                        top: 8 * boxScale,
                        right: 8 * boxScale,
                        child: IconButton(
                          onPressed: () => Navigator.of(context)
                              .pop(LoginPromptResult.dismissed),
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      // Elevated glowing lock badge
                      Center(
                        child: Container(
                          width: 64 * boxScale,
                          height: 64 * boxScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? c.card : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 30 * boxScale,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content body
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24 * boxScale,
                    20 * boxScale,
                    24 * boxScale,
                    20 * boxScale,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'auth.login_required_title'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 21 * typeScale,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8 * boxScale),
                      Text(
                        'auth.login_required_desc'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14 * typeScale,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 16 * boxScale),
                      // Feature preview chips explaining what requires login
                      _FeaturePillsRow(
                          boxScale: boxScale, typeScale: typeScale),
                      SizedBox(height: 22 * boxScale),
                      // Primary CTA: Login Now
                      _LoginButton(
                        boxScale: boxScale,
                        typeScale: typeScale,
                        onTap: () {
                          // Close dialog first, then route so login screen animates
                          // over the host screen.
                          Navigator.of(context).pop(LoginPromptResult.login);
                          Navigator.of(context).pushNamed(Static.login);
                        },
                      ),
                      SizedBox(height: 10 * boxScale),
                      // Secondary Action: Later
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(LoginPromptResult.dismissed),
                        style: TextButton.styleFrom(
                          minimumSize: Size.fromHeight(46 * boxScale),
                          foregroundColor: c.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14 * boxScale),
                          ),
                          textStyle: TextStyle(
                            fontSize: 14.5 * typeScale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text('auth.later'.tr),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePillsRow extends StatelessWidget {
  const _FeaturePillsRow({
    required this.boxScale,
    required this.typeScale,
  });

  final double boxScale;
  final double typeScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.appColors;

    final items = [
      (Icons.location_on_rounded, 'shell.guest.visits'.tr),
      (Icons.groups_rounded, 'shell.guest.depots'.tr),
      (Icons.description_rounded, 'shell.guest.quotations'.tr),
      (Icons.inventory_2_rounded, 'shell.guest.orders'.tr),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8 * boxScale,
      runSpacing: 8 * boxScale,
      children: [
        for (final (icon, label) in items)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10 * boxScale,
              vertical: 6 * boxScale,
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10 * boxScale),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14 * boxScale, color: scheme.primary),
                SizedBox(width: 6 * boxScale),
                Text(
                  label,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12 * typeScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.onTap,
    required this.boxScale,
    required this.typeScale,
  });

  final VoidCallback onTap;
  final double boxScale;
  final double typeScale;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16 * boxScale);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.brandNavyDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 50 * boxScale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.login_rounded,
                  color: Colors.white,
                  size: 20 * boxScale,
                ),
                SizedBox(width: 10 * boxScale),
                Text(
                  'auth.login_now'.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5 * typeScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
