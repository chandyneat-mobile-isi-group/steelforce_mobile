import 'dart:async';
import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/sign_in_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/reset/auth_reset_scaffold.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/verify/otp_field.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

class VerifyResult {
  const VerifyResult.success([this.message]) : isSuccess = true;
  const VerifyResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String? message;
}

/// Outcome of a resend, returned by [VerifyScreen.onResend].
class ResendResult {
  const ResendResult.sent({this.cooldown}) : message = null;
  const ResendResult.failure(String this.message, {this.cooldown});

  /// User-facing failure; null when a new code was requested.
  final String? message;

  /// The server's wait before the next request. Null keeps
  /// [VerifyScreen.resendCooldown] after a send, and no wait after a failure.
  final Duration? cooldown;

  bool get isSuccess => message == null;
}

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({
    super.key,
    required this.target,
    required this.onVerify,
    this.onVerified,
    this.onResend,
    this.onBackToLogin,
    this.codeLength = 6,
    this.resendCooldown = const Duration(seconds: 30),
    this.autoVerify = false,
    this.automaticProofAvailable,
    this.showVerifyButton = true,
  });

  final String target;
  final Future<VerifyResult> Function(String code) onVerify;
  final ValueChanged<String>? onVerified;

  final Future<ResendResult> Function()? onResend;
  final VoidCallback? onBackToLogin;
  final int codeLength;
  final Duration resendCooldown;

  /// The number was already verified without a code (Android instant
  /// verification on the Firebase reset path): call [onVerify] once on open,
  /// with an empty code, instead of waiting for the rep to type one.
  final bool autoVerify;

  /// Completes if Android retrieves the SMS after `codeSent` has opened this
  /// screen. Manual entry remains available while it is pending.
  final Future<String>? automaticProofAvailable;
  final bool showVerifyButton;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _otpKey = GlobalKey<OtpFieldState>();

  AuthVibeStatus _status = AuthVibeStatus.idle;
  String? _errorMessage;
  Timer? _cooldownTimer;
  int _secondsLeft = 0;

  /// A resend is in flight; a second tap must not start another.
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    if (widget.autoVerify) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verify('');
      });
    } else {
      widget.automaticProofAvailable?.then((_) {
        if (mounted && _status != AuthVibeStatus.verifying) _verify('');
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown([Duration? duration]) {
    _cooldownTimer?.cancel();
    setState(
        () => _secondsLeft = (duration ?? widget.resendCooldown).inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _submit([String? autoCode]) async {
    final codeOk = _otpKey.currentState?.validate() ?? false;
    if (!codeOk) return;

    await _verify(autoCode ?? _otpKey.currentState!.value);
  }

  Future<void> _verify(String code) async {
    if (_status == AuthVibeStatus.verifying ||
        _status == AuthVibeStatus.success) {
      return;
    }
    debugTrace('password-reset.ui', 'OTP verification submitted');
    setState(() {
      _status = AuthVibeStatus.verifying;
      _errorMessage = null;
    });

    final result = await widget.onVerify(code);
    debugTrace(
      'password-reset.ui',
      result.isSuccess
          ? 'OTP verification succeeded'
          : 'OTP verification failed',
    );

    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _status = AuthVibeStatus.success);
      if (widget.onVerified != null) {
        widget.onVerified!(code);
      } else {
        _navigateToCreateNewPassword(code);
      }
    } else {
      setState(() {
        _status = AuthVibeStatus.error;
        _errorMessage = result.message ?? 'auth.invalid_code'.tr;
      });
      _otpKey.currentState?.clear();
    }
  }

  Future<void> _resend() async {
    if (_resending || _secondsLeft > 0 || widget.onResend == null) return;
    debugTrace('password-reset.ui', 'resend requested');
    setState(() {
      _resending = true;
      _status = AuthVibeStatus.idle;
      _errorMessage = null;
    });
    _otpKey.currentState?.clear();
    final result = await widget.onResend!();
    if (!mounted) return;
    setState(() => _resending = false);
    if (!result.isSuccess) {
      debugTrace('password-reset.ui', 'resend failed');
      setState(() {
        _status = AuthVibeStatus.error;
        _errorMessage = result.message;
      });
      // A rate-limited resend waits out the server's interval, not ours.
      if (result.cooldown != null) _startCooldown(result.cooldown);
      return;
    }
    debugTrace('password-reset.ui', 'resend accepted');
    _startCooldown(result.cooldown);
  }

  void _navigateToCreateNewPassword(String code) {
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(
      Static.createNewPassword,
      arguments: {'target': widget.target, 'code': code},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthResetScaffold(
      onBack: widget.onBackToLogin ?? () => Navigator.of(context).maybePop(),
      mascotAsset: CoachMascot.verifyCodeAsset,
      title: 'auth.verify_code_title'.tr,
      accentLastWord: true,
      subtitle: 'auth.verify_code_subtitle'.trParams({'target': widget.target}),
      card: _form(),
    );
  }

  Widget _form() {
    final canResend =
        !_resending && _secondsLeft == 0 && widget.onResend != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OtpField(
          key: _otpKey,
          length: widget.codeLength,
          onCompleted: _submit,
          onDark: true,
        ),
        SizedBox(height: context.rh(16)),
        StatusPill(status: _status, message: _errorMessage, onDark: true),
        if (widget.showVerifyButton) ...[
          SignInButton(
            label: 'auth.verify'.tr,
            iconTrailing: true,
            loading: _status == AuthVibeStatus.verifying,
            onPressed: () => _submit(),
          ),
          SizedBox(height: context.rh(12)),
        ],
        const _ShieldDivider(),
        SizedBox(height: context.rh(4)),
        Center(
          child: TextButton(
            onPressed: canResend ? _resend : null,
            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
            child: _secondsLeft > 0
                ? _countdown(context)
                : Text(
                    'auth.resend_code'.tr,
                    style: TextStyle(
                      color: canResend ? AuthInk.accent : AuthInk.muted,
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// "Resend code in **59s**": the number in the lit blue.
  Widget _countdown(BuildContext context) {
    const mark = '\u0000';
    final parts = 'auth.resend_code_in'.trParams({'seconds': mark}).split(mark);
    final base = TextStyle(
      color: AuthInk.muted,
      fontSize: context.rsp(15),
    );
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: parts.first),
        TextSpan(
          text: '$_secondsLeft',
          style: const TextStyle(
            color: AuthInk.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (parts.length > 1) TextSpan(text: parts.sublist(1).join()),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// line — shield — line, between the code and the resend.
class _ShieldDivider extends StatelessWidget {
  const _ShieldDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(
        height: 1,
        color: AuthInk.fieldBorder,
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.rw(12)),
          child: Icon(
            Icons.verified_user_outlined,
            color: AuthInk.accent,
            size: context.rr(22),
          ),
        ),
        line,
      ],
    );
  }
}
