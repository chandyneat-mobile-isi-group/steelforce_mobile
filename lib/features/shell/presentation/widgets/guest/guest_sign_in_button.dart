import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// The guest landing's one call to action: a white button with navy text,
/// the brightest thing on the navy panel.
class GuestSignInButton extends StatelessWidget {
  const GuestSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandNavy,
        minimumSize: Size.fromHeight(context.rh(54).clamp(48.0, 64.0)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rr(12)),
        ),
        // From the theme, so the label keeps the app's Latin/Khmer family.
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: context.rsp(17),
              fontWeight: FontWeight.w700,
            ),
      ),
      child: Text('auth.login_btn'.tr),
    );
  }
}
