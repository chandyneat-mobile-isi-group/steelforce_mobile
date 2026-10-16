import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_otp_args.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/shared/widgets/aurora_background.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Outcome of a forgot-password request, returned by [ForgotPasswordScreen.onSubmit].
class ForgotPasswordResult {
  const ForgotPasswordResult.success([this.message]) : isSuccess = true;
  const ForgotPasswordResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String? message;
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onSubmit,
    this.onBackToLogin,
  });

  final Future<ForgotPasswordResult> Function(String identifier) onSubmit;
  final VoidCallback? onBackToLogin;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneKey = GlobalKey<PhoneNumberFieldState>();

  AuthVibeStatus _status = AuthVibeStatus.idle;
  String? _errorMessage;
  String? _sentTo;

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final phoneOk = _phoneKey.currentState?.validate() ?? false;
    if (!formOk || !phoneOk) return;

    final identifier = _phoneKey.currentState!.value;

    setState(() {
      _status = AuthVibeStatus.verifying;
      _errorMessage = null;
    });

    final result = await widget.onSubmit(identifier);

    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        _status = AuthVibeStatus.success;
        _sentTo = identifier;
      } else {
        _status = AuthVibeStatus.error;
        _errorMessage = result.message ?? 'auth.something_went_wrong'.tr;
      }
    });

    // Straight to the code screen, tagged as the reset journey so it routes on
    // to "create new password" rather than into the app.
    //
    // `forgot-password` always reports success whether or not the address
    // exists — otherwise the endpoint becomes an account-enumeration oracle —
    // so this navigates on success without implying the address was found.
    if (result.isSuccess && mounted) {
      await Navigator.of(context).pushNamed(
        Static.verifyOtp,
        arguments: VerifyOtpArgs.passwordReset(target: identifier),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine max width based on the viewport size class
    final maxCardWidth = context.responsive(
      compact: 420.0,
      medium: 520.0,
      expanded: 600.0,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                _BackButton(onPressed: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      // FIXED: Applied dynamic EdgeInsets based on context.pagePadding
                      padding: EdgeInsets.all(context.pagePadding),
                      child: ConstrainedBox(
                        // FIXED: Replaced hardcoded 420 with responsive constraint
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  _status == AuthVibeStatus.success
                                      ? Icons.mark_email_read_outlined
                                      : Icons.lock_reset_outlined,
                                  size: context.rr(40),
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                SizedBox(height: context.rh(18)),
                                Text(
                                  _status == AuthVibeStatus.success
                                      ? 'auth.check_your_inbox'.tr
                                      : 'auth.forgot_password_title'.tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: context.rsp(26),
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: context.rh(8)),
                                Text(
                                  _status == AuthVibeStatus.success
                                      ? 'auth.reset_instructions_sent'
                                          .trParams({'target': _sentTo ?? ''})
                                      : 'auth.forgot_password_subtitle'.tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.appColors.textSecondary,
                                      fontSize: context.rsp(15)),
                                ),
                              ],
                            ),
                            SizedBox(height: context.rh(24)),
                            GlassCard(
                              child: _status == AuthVibeStatus.success
                                  ? _SuccessActions(
                                      onBackToLogin: widget.onBackToLogin,
                                      onResend: () => setState(
                                          () => _status = AuthVibeStatus.idle),
                                    )
                                  : _form(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone only, matching the sign-in screen: the sales app has no
          // e-mail-based identity path, and offering one here would be a
          // second door into a reset flow that only takes phone numbers.
          PhoneNumberField(
            key: _phoneKey,
            required: true,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: context.rh(6)),
          StatusPill(
            status: _status,
            message: _errorMessage,
          ),
          GradientButton(
            label: 'auth.send_reset_link'.tr,
            loading: _status == AuthVibeStatus.verifying,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _SuccessActions extends StatelessWidget {
  const _SuccessActions({this.onBackToLogin, this.onResend});

  final VoidCallback? onBackToLogin;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientButton(
          label: 'auth.back_to_login'.tr,
          onPressed: onBackToLogin,
        ),
        SizedBox(height: context.rh(12)),
        Center(
          child: TextButton(
            onPressed: onResend,
            child: Text(
              'auth.resend_or_try_different'.tr,
              style: TextStyle(
                  color: context.appColors.info, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // FIXED: Applied responsive relative constraints to the back button padding
      padding: EdgeInsets.only(left: context.rw(8), top: context.rh(4)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(Icons.arrow_back_ios_new, size: context.rr(18)),
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
