import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_form_card.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_background.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:steelforce/shared/widgets/brand_logo.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// The page every password step shares — security check, phone, code, new
/// password — so the journey reads as one place with the sign-in screen:
/// the white brand backdrop, a round back button, the mascot acting out the
/// step under a soft glow, a two-tone title, and the form in the same white
/// card as sign-in.
///
/// Dark in both themes, like sign-in.
class AuthResetScaffold extends StatelessWidget {
  const AuthResetScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.card,
    required this.onBack,
    this.mascotAsset = CoachMascot.asset,
    this.accentLastWord = false,
    this.titleBadge,
    this.showBrand = false,
    this.alignStart = false,
    this.tagline,
  });

  final String title;
  final String subtitle;

  /// The form; drawn inside an [AuthFormCard].
  final Widget card;
  final VoidCallback onBack;
  final String mascotAsset;

  /// Draws the title's last word in the lit blue ("Verify **Code**"). A title
  /// with no space (most Khmer) stays white.
  final bool accentLastWord;

  /// An icon in a small glass tile before the title.
  final IconData? titleBadge;

  /// The SteelForce lockup above the mascot.
  final bool showBrand;

  /// Title and subtitle start-aligned instead of centred.
  final bool alignStart;

  /// A quiet line under the card, e.g. "SAFE • SECURE • TOGETHER".
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final insets = context.deviceInsets;
    final keyboardOpen = insets.isKeyboardOpen;
    final isLandscape = screen.width > screen.height;
    final isTabletLandscape = screen.width >= 960 && isLandscape;
    final isTabletPortrait =
        (screen.shortestSide >= 600 || !context.isCompactWindow) &&
            !isLandscape;
    final dense = screen.height < 720;
    final gutter = context.pagePadding;

    final maxWidth = context.responsive(
      compact: 440.0,
      medium: 480.0,
      expanded: 500.0,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: AuthLightTheme(
          child: Scaffold(
        // The content pads for the keyboard itself, so the backdrop never
        // squashes when it opens.
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              const Positioned.fill(child: LoginBackground()),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(bottom: insets.keyboard),
                  child: isTabletLandscape
                      ? _buildTabletLandscape(
                          context, gutter, dense, keyboardOpen)
                      : isTabletPortrait
                          ? _buildTabletPortrait(
                              context,
                              gutter,
                              maxWidth,
                              dense,
                              keyboardOpen,
                            )
                          : _buildPhoneLayout(
                              context,
                              gutter,
                              maxWidth,
                              dense,
                              keyboardOpen,
                            ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildTabletLandscape(
    BuildContext context,
    double gutter,
    bool dense,
    bool keyboardOpen,
  ) {
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: gutter,
              top: context.rh(8),
            ),
            child: _GlassBackButton(onPressed: onBack),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: gutter * 1.5,
                vertical: context.rh(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.only(end: context.rw(32)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showBrand) ...[
                              BrandLogo(
                                width: context.rr(200).clamp(170.0, 240.0),
                                ink: BrandLogoInk.dark,
                              ),
                              SizedBox(height: context.rh(14)),
                            ],
                            _GlowingMascot(
                              size: context.rh(130),
                              asset: mascotAsset,
                            ),
                            SizedBox(height: context.rh(14)),
                            _Title(
                              text: title,
                              accentLastWord: accentLastWord,
                              badge: titleBadge,
                              align: TextAlign.start,
                            ),
                            SizedBox(height: context.rh(8)),
                            Text(
                              subtitle,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: AuthInk.muted,
                                fontSize: context.rsp(16),
                                height: 1.4,
                              ),
                            ),
                            if (tagline != null) ...[
                              SizedBox(height: context.rh(20)),
                              _Tagline(text: tagline!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AuthFormCard(child: card),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletPortrait(
    BuildContext context,
    double gutter,
    double maxWidth,
    bool dense,
    bool keyboardOpen,
  ) {
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: gutter,
              top: context.rh(10),
            ),
            child: _GlassBackButton(onPressed: onBack),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                gutter,
                context.rh(12),
                gutter,
                context.rh(24),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _content(context, dense, keyboardOpen),
              ),
            ),
          ),
        ),
        if (tagline != null && !keyboardOpen)
          Padding(
            padding: EdgeInsets.only(bottom: context.rh(22)),
            child: _Tagline(text: tagline!),
          ),
      ],
    );
  }

  Widget _buildPhoneLayout(
    BuildContext context,
    double gutter,
    double maxWidth,
    bool dense,
    bool keyboardOpen,
  ) {
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: gutter,
              top: context.rh(6),
            ),
            child: _GlassBackButton(onPressed: onBack),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, context.rh(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _content(context, dense, keyboardOpen),
              ),
            ),
          ),
        ),
        if (tagline != null && !keyboardOpen)
          Padding(
            padding: EdgeInsets.only(bottom: context.rh(18)),
            child: _Tagline(text: tagline!),
          ),
      ],
    );
  }

  Widget _content(BuildContext context, bool dense, bool keyboardOpen) {
    final cross =
        alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = alignStart ? TextAlign.start : TextAlign.center;
    // The art gives way first when the keyboard needs the room.
    final mascot = context.rh(keyboardOpen ? 96 : (dense ? 140 : 176));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBrand && !keyboardOpen) ...[
          Center(
            child: BrandLogo(
              width: context.rr(200).clamp(170.0, 240.0),
              ink: BrandLogoInk.dark,
            ),
          ),
          SizedBox(height: context.rh(dense ? 6 : 12)),
        ],
        Center(child: _GlowingMascot(size: mascot, asset: mascotAsset)),
        SizedBox(height: context.rh(dense ? 8 : 14)),
        Column(
          crossAxisAlignment: cross,
          children: [
            _Title(
              text: title,
              accentLastWord: accentLastWord,
              badge: titleBadge,
              align: textAlign,
            ),
            SizedBox(height: context.rh(8)),
            Text(
              subtitle,
              textAlign: textAlign,
              style: TextStyle(
                color: AuthInk.muted,
                fontSize: context.rsp(16),
                height: 1.4,
              ),
            ),
          ],
        ),
        SizedBox(height: context.rh(dense ? 18 : 26)),
        AuthFormCard(child: card),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.text,
    required this.accentLastWord,
    required this.badge,
    required this.align,
  });

  final String text;
  final bool accentLastWord;
  final IconData? badge;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final khmer = LocalizationService.instance.currentLanguageCode == 'km';
    final style = TextStyle(
      color: AuthInk.text,
      fontSize: context.rsp(khmer ? 26 : 32),
      fontWeight: FontWeight.w800,
      letterSpacing: khmer ? 0 : -0.4,
      height: khmer ? 1.4 : 1.15,
    );
    final split = accentLastWord ? text.lastIndexOf(' ') : -1;
    final words = split <= 0
        ? TextSpan(text: text)
        : TextSpan(children: [
            TextSpan(text: text.substring(0, split + 1)),
            TextSpan(
              text: text.substring(split + 1),
              style: const TextStyle(color: AuthInk.accent),
            ),
          ]);
    final heading = Semantics(
      header: true,
      child: Text.rich(words, textAlign: align, style: style),
    );
    if (badge == null) return heading;

    final tile = context.rr(44);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            color: AuthInk.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(context.rr(12)),
            border: Border.all(
              color: AuthInk.fieldBorder,
            ),
          ),
          child: Icon(badge, color: AuthInk.text, size: context.rr(24)),
        ),
        SizedBox(width: context.rw(12)),
        Flexible(child: heading),
      ],
    );
  }
}

/// The mascot over a soft blue halo, as if lit from behind.
class _GlowingMascot extends StatelessWidget {
  const _GlowingMascot({required this.size, required this.asset});

  final double size;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.3,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.signalBlue.withValues(alpha: 0.18),
                AppColors.signalBlue.withValues(alpha: 0.0),
              ]),
            ),
            child: SizedBox.square(dimension: size * 1.2),
          ),
          CoachMascot(size: size, animationAsset: asset),
        ],
      ),
    );
  }
}

/// A round glass back button, clear of the edge.
class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = context.rr(46).clamp(44.0, 52.0);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AuthInk.fieldFill,
          border: Border.all(
            color: AuthInk.fieldBorder,
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'common.back'.tr,
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: context.rr(18)),
          color: AuthInk.text,
        ),
      ),
    );
  }
}

/// line — shield — line, over a spaced-out caption.
class _Tagline extends StatelessWidget {
  const _Tagline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(
          width: context.rw(84),
          height: 1,
          color: AuthInk.fieldBorder,
        );
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              line(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.rw(10)),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: AuthInk.accent,
                  size: context.rr(22),
                ),
              ),
              line(),
            ],
          ),
          SizedBox(height: context.rh(8)),
          Text(
            text,
            style: TextStyle(
              color: AuthInk.accent,
              fontSize: context.rsp(11),
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
    );
  }
}
