import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/config/feature_flags.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/notification_coordinator.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_badge_cubit.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';

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

  // Traditional Gold Palette
  static const Color _goldLight = Color(0xFFF3E5AB);
  static const Color _goldPrimary = Color(0xFFD4AF37);
  static const Color _goldDark = Color(0xFF996515);

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
                  color: _goldPrimary.withValues(alpha: 0.35),
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
                _AppBarMedallionButton(
                  isHome: false,
                  onTap: onBackToHomeTap,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: scheme.onSurface,
                    size: context.rr(16),
                  ),
                ),
                SizedBox(width: context.rw(12)),
              ],

              // 2. Main Content (Logo or Title)
              Expanded(
                child: isHome
                    ? Align(
                        alignment: Alignment.centerLeft,
                        // The mark doubles as the entry point to About &
                        // Information. Wrapped in Semantics because an image
                        // alone gives a screen reader nothing to announce, and
                        // this one is now a control.
                        child: Semantics(
                          button: true,
                          label: 'about.title'.tr,
                          child: PressScale(
                            onTap: onLogoTap,
                            // `BrandLogo`, not a raw asset. What stood here
                            // was `Image.asset` pointed at an `.svg` — which
                            // Image cannot decode — at a path that does not
                            // exist, sized 150×50 with `BoxFit.cover`, a box
                            // narrower than the artwork's 2.75:1 and so
                            // cropping the wordmark. BrandLogo picks the ink
                            // from the surface and derives the height from the
                            // artwork, which is the whole reason it exists.
                            child: _LogoGlow(
                              child: BrandLogo(
                                width: context.rw(120),
                                // The approved two-tone navy mark. It is only
                                // legible on white, so it sits on a soft white
                                // glow that fades into the photo — a light
                                // surface without the hard edge of a plate.
                                ink: BrandLogoInk.brand,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Text(
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
                      ),
              ),
              SizedBox(width: context.rw(12)),

              // 3. Notification Bell — 3D Medallion
              CoachKeys.wrap(
                CoachKeys.notification,
                child: _NotificationBell(
                  isInverseColor: isHome,
                  onTapOverride: onNotificationTap,
                ),
              ),
              SizedBox(width: context.rw(10)),

              // 4. User Avatar — 3D Traditional Gold Frame
              CoachKeys.wrap(
                CoachKeys.profile,
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    width: context.rr(38),
                    height: context.rr(38),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      // Gold Metallic Outer Rim Frame
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_goldLight, _goldPrimary, _goldDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isHome ? 0.35 : 0.15),
                          offset: const Offset(0, 2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(1.5.r), // Gold Border Width
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(10.5.r),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _AvatarImage(
                        url: avatarUrl,
                        initials: avatarInitials,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft white glow behind the navy wordmark on the home hero.
///
/// A rounded white shape blurred well past its own edge, so it lifts the dark
/// mark off the photo and feathers out with no visible border — unlike a plate
/// or a `BoxShadow`, both of which keep a solid core with a readable outline.
class _LogoGlow extends StatelessWidget {
  const _LogoGlow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sigma = context.rr(14);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -context.rw(14),
          right: -context.rw(14),
          top: -context.rh(10),
          bottom: -context.rh(10),
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(context.rr(40)),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 3D Tactile Medallion Container for App Bar Actions
class _AppBarMedallionButton extends StatelessWidget {
  const _AppBarMedallionButton({
    required this.child,
    this.onTap,
    this.isHome = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool isHome;

  static const Color _goldPrimary = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.rr(36),
        height: context.rr(36),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isHome
                ? [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : [
                    scheme.surface,
                    Color.lerp(scheme.surface, scheme.onSurface, 0.05)!,
                  ],
          ),
          border: Border.all(
            color: _goldPrimary.withValues(alpha: isHome ? 0.6 : 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isHome ? 0.3 : (isDark ? 0.35 : 0.08),
              ),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({this.isInverseColor = false, this.onTapOverride});
  final bool isInverseColor;
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget buildBellIcon(bool hasNotifications) {
      return _AppBarMedallionButton(
        isHome: isInverseColor,
        onTap: onTapOverride ??
            () => showNotificationsSheet(
                  context: context,
                  // Routing a tapped row is the coordinator's job: the backend
                  // builds every `deep_link` (§11) and exactly one place resolves
                  // them. The sheet pops first so the destination is not raised
                  // underneath it.
                  onOpenNotification: (notification) {
                    Navigator.of(context).pop();
                    sl<NotificationCoordinator>()
                        .openLink(notification.deepLink);
                  },
                ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: isInverseColor ? Colors.white : scheme.onSurface,
              size: context.rr(20),
            ),
            if (hasNotifications)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: context.rr(9),
                  height: context.rr(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isInverseColor ? Colors.black38 : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.error.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // No dot while notifications are switched off: it would point at a
    // "coming soon" sheet.
    if (onTapOverride != null || !FeatureFlags.notifications) {
      return buildBellIcon(false);
    }

    // Bound to the app-wide badge cubit rather than a `FutureBuilder`.
    //
    // The previous version re-ran a fetch on every app-bar rebuild — which is
    // every tab change — and showed a dot that was already stale by the time it
    // painted. This reads the local mirror, so it moves the instant a
    // notification arrives, the instant one is read, and correctly while
    // offline.
    //
    // The dot shows **unread** (§5.4): the bell answers "is there something to
    // look at". The app-icon badge is a different number — outstanding actions —
    // and is set by the backend in `aps.badge`.
    return BlocSelector<NotificationBadgeCubit, NotificationCounts, bool>(
      bloc: sl<NotificationBadgeCubit>(),
      selector: (counts) => counts.hasUnread,
      builder: (context, hasUnread) => buildBellIcon(hasUnread),
    );
  }
}

/// The user's own picture in the app bar — never a stock image, which reads
/// as somebody else's face on the account.
///
/// Picture → initials → person icon, in that order of what is known.
class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.initials});

  final String? url;
  final String? initials;

  static const Color _gold = Color.fromARGB(255, 195, 172, 0);

  @override
  Widget build(BuildContext context) {
    final letters = initials?.trim() ?? '';
    final fallback = letters.isEmpty
        ? Icon(Icons.person, color: _gold, size: context.rr(18))
        : Center(
            child: Text(
              letters,
              // Fixed-size badge: initials must not grow with the text scale.
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: _gold,
                fontSize: context.rr(13),
                fontWeight: FontWeight.w800,
              ),
            ),
          );

    final address = url;
    if (address == null) return fallback;
    return CachedNetworkImage(
      imageUrl: address,
      fit: BoxFit.cover,
      memCacheWidth:
          (context.rr(38) * MediaQuery.devicePixelRatioOf(context)).round(),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
