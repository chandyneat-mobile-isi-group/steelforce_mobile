import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_fade_in.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_feature_strip.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_landing_brand.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_landing_footer.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_landing_hero.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_sign_in_button.dart';

/// The guest (signed-out) home: a full-screen landing — brand, illustration,
/// what the app does, and one way in.
///
/// Fits one portrait phone screen without scrolling; on a short screen or
/// with large text it scrolls rather than clipping. On a wide window the
/// content keeps a phone-like width, centred, while the background and the
/// footer sweep run edge to edge.
class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key, required this.onLogin});

  /// Opens the shared login prompt.
  final VoidCallback onLogin;

  /// Stagger step between sections.
  static const _step = Duration(milliseconds: 90);

  /// Content width cap on tablets and desktop.
  static const _maxContentWidth = 520.0;

  /// The smallest the illustration is drawn before the page scrolls.
  static const _minHeroHeight = 130.0;

  /// `1.0.0+1` → `1.0.0`: the build number means nothing to a rep.
  static String get _version => DeviceIdentity.appVersion.split('+').first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final footerHeight = media.size.width / GuestLandingFooter.aspectRatio;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // White in light mode, as the artwork is drawn on white — so the
          // illustration blends in instead of sitting in a visible box.
          // The pale sky wash in the top-right corner of the artwork.
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.center,
            colors: [
              // Blended to an opaque colour: a translucent stop would let the
              // shell's grey canvas show through.
              Color.alphaBlend(
                scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                colors.card,
              ),
              colors.card,
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GuestLandingFooter(),
            ),
            SafeArea(
              // Laid out to the screen's height, with the illustration taking
              // whatever is left — so a phone shows it all without scrolling.
              // When even the smallest illustration does not leave room (a
              // short screen, large accessibility text) the page scrolls
              // rather than squeezing or clipping.
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: _maxContentWidth),
                        child: Padding(
                          // Vertical only: the illustration runs edge to edge,
                          // everything else is inset (see [_inset]).
                          padding: EdgeInsets.only(
                            top: context.rh(16),
                            // Clear of the footer sweep's coloured part.
                            bottom: footerHeight * 0.55,
                          ),
                          child: _content(context, colors, isDark),
                        ),
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

  /// The side margin for everything except the illustration.
  static Widget _inset(BuildContext context, Widget child) => Padding(
        padding: EdgeInsets.symmetric(horizontal: context.rw(28)),
        child: child,
      );

  Widget _content(BuildContext context, AppThemeColors colors, bool isDark) {
    final taglineInk =
        isDark ? Theme.of(context).colorScheme.onSurface : AppColors.brandNavy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inset(context, const GuestFadeIn(child: GuestLandingBrand())),
        SizedBox(height: context.rh(8)),
        // The illustration absorbs the spare height. The SizedBox is its
        // *minimum*: Expanded overrides its height when there is more room,
        // but it is what the page reports as the least it needs — below
        // that, the page scrolls.
        Expanded(
          child: SizedBox(
            height: context.rh(_minHeroHeight),
            child: Center(
              child: GuestFadeIn(
                delay: _step,
                child: GuestLandingHero(maxHeight: context.rh(360)),
              ),
            ),
          ),
        ),
        SizedBox(height: context.rh(16)),
        _inset(
          context,
          GuestFadeIn(
            delay: _step * 2,
            child: Text(
              'shell.guest.tagline'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: taglineInk,
                fontSize: context.rsp(21),
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        SizedBox(height: context.rh(20)),
        _inset(
          context,
          GuestFadeIn(
            delay: _step * 3,
            child: GuestFeatureStrip(onRequireLogin: onLogin),
          ),
        ),
        SizedBox(height: context.rh(24)),
        _inset(
          context,
          GuestFadeIn(
            delay: _step * 4,
            child: GuestSignInButton(onPressed: onLogin),
          ),
        ),
        SizedBox(height: context.rh(14)),
        Text(
          'shell.guest.version'.trParams({'version': _version}),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: context.rsp(13),
          ),
        ),
      ],
    );
  }
}
