import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_otp_args.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/sign_in_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/reset/auth_reset_scaffold.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// Outcome of a forgot-password request, returned by [ForgotPasswordScreen.onSubmit].
class ForgotPasswordResult {
  const ForgotPasswordResult.success({this.message, this.phoneVerification})
      : isSuccess = true,
        cooldown = null;
  const ForgotPasswordResult.failure(this.message, {this.cooldown})
      : isSuccess = false,
        phoneVerification = null;

  final bool isSuccess;
  final String? message;
  final Duration? cooldown;

  /// The Firebase verification session, handed on to the code screen. Null
  /// when the backend sent the code.
  final PhoneVerificationHandle? phoneVerification;
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
  bool _firebaseReset = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(Duration duration) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = duration.inSeconds.clamp(0, 86400));
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _submit() async {
    // One request at a time: each start spends one of the server's
    // per-number allowance.
    if (_status == AuthVibeStatus.verifying) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final phoneOk = _phoneKey.currentState?.validate() ?? false;
    if (!formOk || !phoneOk || _cooldownSeconds > 0) return;

    final identifier = _phoneKey.currentState!.value;
    debugTrace('password-reset.ui', 'phone entry submitted');

    setState(() {
      _status = AuthVibeStatus.verifying;
      _errorMessage = null;
    });

    final result = await widget.onSubmit(identifier);
    debugTrace(
      'password-reset.ui',
      result.isSuccess
          ? 'verification request accepted; opening OTP step'
          : 'verification request did not proceed',
    );

    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        _status = AuthVibeStatus.success;
        _sentTo = result.phoneVerification?.phoneNumber ?? identifier;
        _firebaseReset = result.phoneVerification != null;
      } else {
        _status = AuthVibeStatus.error;
        _errorMessage = result.message ?? 'auth.something_went_wrong'.tr;
      }
    });
    if (!result.isSuccess && result.cooldown != null) {
      _startCooldown(result.cooldown!);
    }

    // Straight to the code screen, tagged as the reset journey so it routes on
    // to "create new password" rather than into the app.
    //
    // `forgot-password` always reports success whether or not the address
    // exists — otherwise the endpoint becomes an account-enumeration oracle —
    // so this navigates on success without implying the address was found.
    if (result.isSuccess && mounted) {
      await Navigator.of(context).pushNamed(
        Static.verifyOtp,
        arguments: VerifyOtpArgs.passwordReset(
          target: result.phoneVerification?.phoneNumber ?? identifier,
          phoneVerification: result.phoneVerification,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _status == AuthVibeStatus.success;
    return AuthResetScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      showBrand: true,
      mascotAsset: CoachMascot.phoneEntryAsset,
      title:
          sent ? 'auth.check_your_inbox'.tr : 'auth.forgot_password_title'.tr,
      subtitle: sent
          ? _firebaseReset
              ? 'auth.reset_phone_neutral'.tr
              : 'auth.reset_instructions_sent'
                  .trParams({'target': _sentTo ?? ''})
          : 'auth.forgot_password_subtitle'.tr,
      tagline: 'auth.tagline_simple'.tr,
      card: sent
          ? _SuccessActions(
              onBackToLogin: widget.onBackToLogin,
              onResend: () => setState(() => _status = AuthVibeStatus.idle),
            )
          : _form(),
    );
  }

  String? get _cooldownLabel => _cooldownSeconds > 0
      ? 'auth.try_again_in'.trParams({
          'time': _formatCooldown(_cooldownSeconds),
        })
      : null;

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
            onPhoto: true,
            showRequiredMark: true,
            textInputAction: TextInputAction.done,
          ),
          SizedBox(height: context.rh(18)),
          StatusPill(
            status: _status,
            message: _errorMessage,
            verifyingLabel: 'auth.reset_verifying_securely'.tr,
            onDark: true,
          ),
          SignInButton(
            label: _cooldownLabel ?? 'auth.send_reset_link'.tr,
            iconTrailing: true,
            loading: _status == AuthVibeStatus.verifying,
            onPressed: _cooldownSeconds > 0 ? null : _submit,
          ),
        ],
      ),
    );
  }

  String _formatCooldown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
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
        SignInButton(
          label: 'auth.back_to_login'.tr,
          iconTrailing: true,
          onPressed: onBackToLogin,
        ),
        SizedBox(height: context.rh(8)),
        Center(
          child: TextButton(
            onPressed: onResend,
            style: TextButton.styleFrom(
              foregroundColor: AuthInk.accent,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              'auth.resend_or_try_different'.tr,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
