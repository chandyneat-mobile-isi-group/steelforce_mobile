import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// A premium, brand-styled confirmation dialog shown when a user requests to log out.
///
/// Features the SteelForce [BrandWallpaperBackground] with fine brand zigzags,
/// a prominent danger/logout icon badge, clear descriptive copy, an informative
/// safety reminder card, and ergonomic action buttons.
class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

  /// Shows the dialog with a smooth scale-and-fade transition.
  /// Resolves to `true` when confirmed, or `false` when cancelled/dismissed.
  static Future<bool> show(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'profile.logout_confirm_title'.tr,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const LogoutConfirmDialog(),
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
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      Positioned.fill(
                        child: BrandWallpaperBackground(
                          style: BrandWallpaperStyle.vivid,
                          top: isDark
                              ? const Color(0xFF38131C)
                              : const Color(0xFFC62828),
                          bottom: isDark
                              ? const Color(0xFF1E0B10)
                              : const Color(0xFF8E0000),
                        ),
                      ),
                      // Top-right close button
                      Positioned(
                        top: 8 * boxScale,
                        right: 8 * boxScale,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
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
                      // Elevated logout badge
                      Center(
                        child: Container(
                          width: 64 * boxScale,
                          height: 64 * boxScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? c.card : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            size: 30 * boxScale,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Dialog body
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
                        'profile.logout_confirm_title'.tr,
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
                        'profile.logout_confirm_body'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14 * typeScale,
                          height: 1.45,
                        ),
                      ),
                      SizedBox(height: 16 * boxScale),
                      // Informative security notice card
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * boxScale,
                          vertical: 10 * boxScale,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error
                              .withValues(alpha: isDark ? 0.12 : 0.06),
                          borderRadius: BorderRadius.circular(12 * boxScale),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18 * boxScale,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 10 * boxScale),
                            Expanded(
                              child: Text(
                                'profile.logout_confirm_body'.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12 * typeScale,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 22 * boxScale),
                      // Primary action: Log Out
                      _LogoutButton(
                        boxScale: boxScale,
                        typeScale: typeScale,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                      SizedBox(height: 10 * boxScale),
                      // Secondary action: Cancel
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
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
                        child: Text('profile.cancel'.tr),
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
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
          colors: [Color(0xFFE53935), Color(0xFFC62828)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.32),
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
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 20 * boxScale,
                ),
                SizedBox(width: 10 * boxScale),
                Text(
                  'profile.logout'.tr,
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
