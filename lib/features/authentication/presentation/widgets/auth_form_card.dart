import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// The card the sign-in and password-reset forms sit in, over the white
/// brand backdrop: white with a fine blue-grey rim and a soft lift, so it
/// reads as a sheet laid on the chevron.
///
/// Light in both themes, like the backdrop ([AuthLightTheme]). What goes
/// inside uses the auth ink ([AuthInk]).
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.child, this.padding});

  final Widget child;

  /// Defaults to an even inset.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.rr(26)),
        border: Border.all(color: AuthInk.fieldBorder.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AuthInk.text.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(context.rw(20)),
        child: child,
      ),
    );
  }
}
