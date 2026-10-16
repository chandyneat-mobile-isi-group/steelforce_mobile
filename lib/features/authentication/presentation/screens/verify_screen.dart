import 'dart:async';
import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/verify/otp_field.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/shared/widgets/aurora_background.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';

class VerifyResult {
  const VerifyResult.success([this.message]) : isSuccess = true;
  const VerifyResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String? message;
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
  });

  final String target;
  final Future<VerifyResult> Function(String code) onVerify;
  final ValueChanged<String>? onVerified;
  final Future<void> Function()? onResend;
  final VoidCallback? onBackToLogin;
  final int codeLength;
  final Duration resendCooldown;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _otpKey = GlobalKey<OtpFieldState>();

  AuthVibeStatus _status = AuthVibeStatus.idle;
  String? _errorMessage;
  Timer? _cooldownTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = widget.resendCooldown.inSeconds);
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

    final code = autoCode ?? _otpKey.currentState!.value;

    setState(() {
      _status = AuthVibeStatus.verifying;
      _errorMessage = null;
    });

    final result = await widget.onVerify(code);

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
    if (_secondsLeft > 0 || widget.onResend == null) return;
    setState(() {
      _status = AuthVibeStatus.idle;
      _errorMessage = null;
    });
    _otpKey.currentState?.clear();
    await widget.onResend!();
    if (!mounted) return;
    _startCooldown();
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
                _BackButton(
                  onPressed: widget.onBackToLogin ??
                      () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(context.pagePadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mark_email_unread_outlined,
                                  size: context.rr(44),
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                SizedBox(height: context.rh(18)),
                                Text(
                                  'auth.verify_code_title'.tr,
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
                                  'auth.verify_code_subtitle'
                                      .trParams({'target': widget.target}),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.appColors.textSecondary,
                                    fontSize: context.rsp(15),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: context.rh(24)),
                            GlassCard(child: _form()),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OtpField(
          key: _otpKey,
          length: widget.codeLength,
          onCompleted: _submit,
        ),
        SizedBox(height: context.rh(14)),
        StatusPill(status: _status, message: _errorMessage),
        GradientButton(
          label: 'auth.verify'.tr,
          loading: _status == AuthVibeStatus.verifying,
          onPressed: () => _submit(),
        ),
        SizedBox(height: context.rh(10)),
        Center(
          child: TextButton(
            onPressed:
                (_secondsLeft > 0 || widget.onResend == null) ? null : _resend,
            child: Text(
              _secondsLeft > 0
                  ? 'auth.resend_code_in'.trParams({
                      'seconds': _secondsLeft.toString().padLeft(2, '0'),
                    })
                  : 'auth.resend_code'.tr,
              style: TextStyle(
                color: _secondsLeft > 0
                    ? context.appColors.textSecondary
                    : context.appColors.info,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.w600,
              ),
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
