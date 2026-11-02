import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// The SteelForce lockup in its full colours, top-left, straight on the
/// white auth backdrop.
///
/// The official horizontal lockup, tagline included, drawn from the artwork's
/// own viewBox — never stretched, never re-typeset.
class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key, this.center = false});

  final bool center;

  /// Wide enough for the lockup's tagline to read at arm's length.
  static double logoWidth(BuildContext context) =>
      context.rr(210).clamp(180.0, 260.0);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
      child: BrandLogo(
        width: logoWidth(context),
        ink: BrandLogoInk.dark,
      ),
    );
  }
}

/// "Welcome Back!" · **Grow Together** · **Stronger** · the sign-in line.
///
/// "Grow Together" is the headline; "Stronger" repeats its weight in the
/// sign-in screen's lit blue. [dense] trims the headline on short screens so the form
/// below keeps its room.
class LoginWelcomeSection extends StatelessWidget {
  const LoginWelcomeSection({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    // Khmer stacks vowels and subscripts above and below the line; the tight
    // Latin display leading makes the two headline lines collide.
    final khmer = LocalizationService.instance.currentLanguageCode == 'km';
    final headline = TextStyle(
      color: AuthInk.text,
      fontSize: context.rsp(dense ? 30 : 36),
      fontWeight: FontWeight.w800,
      letterSpacing: khmer ? 0 : -0.6,
      height: khmer ? AppTypography.compactLineHeight : 1.12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'auth.welcome_back'.tr,
          style: TextStyle(
            color: AuthInk.muted,
            fontSize: context.rsp(dense ? 22 : 26),
            fontWeight: FontWeight.w300,
            height: khmer ? AppTypography.compactLineHeight : 1.2,
          ),
        ),
        SizedBox(height: context.rh(dense ? 4 : 8)),
        // One semantic heading for the two-line headline, read as a phrase.
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'auth.headline_grow'.tr),
              const TextSpan(text: '\n'),
              TextSpan(
                text: 'auth.headline_stronger'.tr,
                style: const TextStyle(color: AuthInk.accent),
              ),
            ]),
            style: headline,
          ),
        ),
        SizedBox(height: context.rh(dense ? 10 : 14)),
        Container(
          width: context.rw(68),
          height: 4,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              AuthInk.accent,
              AppColors.signalBlue,
            ]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(height: context.rh(dense ? 10 : 14)),
        Text(
          'auth.sign_in_subtitle'.tr,
          style: TextStyle(
            color: AuthInk.muted,
            fontSize: context.rsp(15),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
