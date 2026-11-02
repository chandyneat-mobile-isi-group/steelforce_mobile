/// The shell's top bar: composes back medallion, logo or title, notification
/// bell, and avatar. Bar background/border lives here; each piece has its own
/// `app_bar_*.dart` file beside this one.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/features/shell/presentation/widgets/app_bar/app_bar_avatar.dart';
import 'package:steelforce/features/shell/presentation/widgets/app_bar/app_bar_brand.dart';
import 'package:steelforce/features/shell/presentation/widgets/app_bar/app_bar_medallion_button.dart';
import 'package:steelforce/features/shell/presentation/widgets/app_bar/app_bar_notification_bell.dart';

class MainAppBar extends StatelessWidget {
  const MainAppBar({
    super.key,
    required this.title,
    required this.onAvatarTap,
    required this.currentTabIndex,
    this.onBackToHomeTap,
    this.onNotificationTap,
    this.onLogoTap,
    this.avatarUrl,
    this.avatarInitials,
  });

  final String title;
  final VoidCallback onAvatarTap;
  final int currentTabIndex;
  final VoidCallback? onBackToHomeTap;
  final VoidCallback? onNotificationTap;

  /// Opens the About & Information centre. Only the home variant shows the
  /// logo, so this is only reachable there.
  final VoidCallback? onLogoTap;

  /// The signed-in user's picture, already absolute. Null for a guest or a
  /// user who never set one.
  final String? avatarUrl;

  /// Shown when there is no picture, or it fails to load. Null or empty
  /// falls back to the generic person icon (a guest).
  final String? avatarInitials;

  @override
  Widget build(BuildContext context) {
    final bool isHome = currentTabIndex == 0;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: AppDurations.medium,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isHome ? Colors.transparent : scheme.surface,
        border: isHome
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.steelRim,
                  width: 1.2,
                ),
              ),
        boxShadow: isHome
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              context.rw(12), context.rh(10), context.rw(16), context.rh(10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Back Button Medallion (Conditionally rendered)
              if (!isHome) ...[
                Semantics(
                  button: true,
                  label: 'common.back'.tr,
                  child: AppBarMedallionButton(
                    isHome: false,
                    onTap: onBackToHomeTap,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: scheme.onSurface,
                      size: context.rr(16),
                    ),
                  ),
                ),
                SizedBox(width: context.rw(12)),
              ],

              // 2. Main Content (Logo or Title)
              Expanded(
                child: isHome ? _buildLogo(context) : _buildTitle(context),
              ),
              SizedBox(width: context.rw(12)),

              // 3. Notification Bell — 3D Medallion
              CoachKeys.wrap(
                CoachKeys.notification,
                child: AppBarNotificationBell(
                  isInverseColor: isHome,
                  onTapOverride: onNotificationTap,
                ),
              ),
              SizedBox(width: context.rw(10)),

              // 4. User Avatar — brand-blue frame
              CoachKeys.wrap(
                CoachKeys.profile,
                child: AppBarAvatar(
                  onTap: onAvatarTap,
                  isHome: isHome,
                  url: avatarUrl,
                  initials: avatarInitials,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      // The mark doubles as the entry point to About & Information. Wrapped in
      // Semantics because an image alone gives a screen reader nothing to
      // announce, and this one is now a control.
      child: Semantics(
        button: true,
        label: 'about.title'.tr,
        child: PressScale(
          onTap: onLogoTap,
          child: const AppBarBrand(),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: context.rsp(18),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
