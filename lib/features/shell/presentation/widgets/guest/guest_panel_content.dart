import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_area_chips.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_fade_in.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_headline.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_landing_brand.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_landing_footer.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_sign_in_button.dart';

/// Everything on the navy panel, top to bottom: brand, headline, the work
/// areas, sign-in and the ISI footer — each fading in a beat after the last.
///
/// Sized by its content; the screen gives the photo whatever is left.
class GuestPanelContent extends StatelessWidget {
  const GuestPanelContent({
    super.key,
    required this.onLogin,
    this.headlineSize = 36,
  });

  final VoidCallback onLogin;
  final double headlineSize;

  static const _step = Duration(milliseconds: 90);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.rw(28),
        context.rh(12),
        context.rw(28),
        context.rh(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GuestFadeIn(child: GuestLandingBrand()),
          SizedBox(height: context.rh(28)),
          GuestFadeIn(
            delay: _step,
            child: GuestHeadline(fontSize: headlineSize),
          ),
          SizedBox(height: context.rh(20)),
          GuestFadeIn(
            delay: _step * 2,
            child: GuestAreaChips(onRequireLogin: onLogin),
          ),
          SizedBox(height: context.rh(32)),
          GuestFadeIn(
            delay: _step * 3,
            child: GuestSignInButton(onPressed: onLogin),
          ),
          SizedBox(height: context.rh(28)),
          GuestFadeIn(delay: _step * 4, child: const GuestLandingFooter()),
        ],
      ),
    );
  }
}
