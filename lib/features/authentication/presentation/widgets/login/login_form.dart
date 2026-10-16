import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/demo_sign_in_hint.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/remember_me_toggle.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/vibe_field.dart';
import 'package:steelforce/routes/app_routes.dart';

/// What the sign-in pill and button show for an auth state.
AuthVibeStatus authVibeStatusFor(AuthState s) {
  if (s is AuthLoadingState) return AuthVibeStatus.verifying;
  if (s is AuthFailureState) return AuthVibeStatus.error;
  if (s is AuthenticatedState) return AuthVibeStatus.success;
  return AuthVibeStatus.idle;
}

/// The sign-in form laid on the login screen's dark base: heading, phone and
/// password, "Remember me", the Sign In button with its failure pill, and
/// the way out as a guest.
///
/// The screen owns the keys, the password controller and what submitting
/// does; this widget owns only whether the password is shown.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.formKey,
    required this.phoneKey,
    required this.password,
    required this.rememberPhone,
    required this.onRememberPhoneChanged,
    required this.onSubmit,
    required this.onContinueAsGuest,
    this.onFillDemoAccount,
  });

  final GlobalKey<FormState> formKey;
  final GlobalKey<PhoneNumberFieldState> phoneKey;
  final TextEditingController password;
  final bool rememberPhone;
  final ValueChanged<bool> onRememberPhoneChanged;
  final VoidCallback onSubmit;
  final VoidCallback onContinueAsGuest;

  /// Set only by a demo build: shows [DemoSignInHint], which fills in the
  /// demo account.
  final VoidCallback? onFillDemoAccount;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    final muted = ink.withValues(alpha: 0.72);

    // One autofill context for the phone + password pair, so iOS Keychain and
    // Android Autofill can fill both from a single saved credential and offer
    // to save the pair afterwards. The fields already carry the right
    // `autofillHints`; without a group around them the platform treats each as
    // an unrelated one-off.
    return AutofillGroup(
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'auth.welcome_back'.tr,
              style: TextStyle(
                color: ink,
                fontSize: context.rsp(26),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              'auth.sign_in_subtitle'.tr,
              style: TextStyle(color: muted, fontSize: context.rsp(14)),
            ),
            SizedBox(height: context.rh(18)),
            // Phone number, as before. The identifier travels to
            // `/mobile/auth/login` as `employeeId`, which the server resolves.
            //
            // NOTE: staging currently answers a phone identifier with
            // `invalid_grant` — it resolves employee IDs (`EMP000201`) and
            // e-mail addresses only. Sign-in by phone therefore depends on the
            // backend accepting phone as an identifier on that endpoint.
            PhoneNumberField(
              key: widget.phoneKey,
              required: true,
              underline: true,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: context.rh(10)),
            VibeField(
              controller: widget.password,
              label: 'auth.password'.tr,
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              underline: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              required: true,
              onSubmitted: (_) => widget.onSubmit(),
              // The reveal toggle, and "Forgot?" right where a rep who cannot
              // remember the password is already looking.
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _obscure
                        ? 'auth.show_password'.tr
                        : 'auth.hide_password'.tr,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: muted,
                      size: context.rr(20),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Static.forgotPassword),
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.symmetric(horizontal: context.rw(4)),
                    ),
                    child: Text(
                      'auth.forgot_short'.tr,
                      semanticsLabel: 'auth.forgot_password'.tr,
                      style: TextStyle(
                        fontSize: context.rsp(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'auth.password_too_short'.tr
                  : null,
            ),
            SizedBox(height: context.rh(10)),
            RememberMeToggle(
              value: widget.rememberPhone,
              onChanged: widget.onRememberPhoneChanged,
            ),
            SizedBox(height: context.rh(18)),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final status = authVibeStatusFor(state);
                return Column(
                  children: [
                    // Failures only. What the pill carries that nothing else
                    // does is the failure message: without it a wrong password
                    // simply stops the spinner and leaves the rep guessing.
                    if (state is AuthFailureState) ...[
                      StatusPill(status: status, message: state.message),
                      SizedBox(height: context.rh(10)),
                    ],
                    GradientButton(
                      // `auth.login_btn` ("Sign In"), not `auth.lets_go`:
                      // the button says what it does.
                      label: 'auth.login_btn'.tr,
                      trailingIcon: Icons.arrow_forward_rounded,
                      loading: status == AuthVibeStatus.verifying,
                      onPressed: widget.onSubmit,
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: context.rh(12)),
            Center(
              child: TextButton(
                onPressed: widget.onContinueAsGuest,
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  'auth.continue_as_guest'.tr,
                  style: TextStyle(
                    fontSize: context.rsp(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Last, so a demo build never pushes Sign In under the keyboard.
            if (widget.onFillDemoAccount case final fill?) ...[
              SizedBox(height: context.rh(12)),
              DemoSignInHint(onFill: fill),
            ],
          ],
        ),
      ),
    );
  }
}
