import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/presentation/bloc/phone_password_change_cubit.dart';
import 'package:steelforce/features/authentication/presentation/bloc/phone_password_change_state.dart';
import 'package:steelforce/features/authentication/presentation/phone_verification_messages.dart';
import 'package:steelforce/features/authentication/presentation/screens/create_new_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/success_screen.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/sign_in_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/reset/auth_reset_scaffold.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// `+85512345678` → `+855 •• ••• 678`: enough for the rep to recognise where
/// the code went, not enough to read the number off the screen.
String maskPhoneNumber(String e164) {
  final digits = e164.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) return '•••';
  final country = digits.startsWith('855') ? '855' : digits.substring(0, 2);
  return '+$country •• ••• ${digits.substring(digits.length - 3)}';
}

/// The signed-in password change, one route for every step so the phone
/// proof lives exactly as long as this screen. Expects a
/// [PhonePasswordChangeCubit] above it.
///
/// Reuses the reset flow's code and new-password screens unchanged.
class PhonePasswordChangeFlow extends StatefulWidget {
  const PhonePasswordChangeFlow({super.key, this.onDone});

  /// After success, or when the rep leaves. Defaults to popping the route.
  final VoidCallback? onDone;

  @override
  State<PhonePasswordChangeFlow> createState() =>
      _PhonePasswordChangeFlowState();
}

class _PhonePasswordChangeFlowState extends State<PhonePasswordChangeFlow> {
  @override
  void initState() {
    super.initState();
    context.read<PhonePasswordChangeCubit>().start();
  }

  void _leave() => (widget.onDone ?? () => Navigator.of(context).maybePop())();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PhonePasswordChangeCubit>();
    return BlocBuilder<PhonePasswordChangeCubit, PhonePasswordChangeState>(
      builder: (context, state) => AnimatedSwitcher(
        duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
            ? Duration.zero
            : const Duration(milliseconds: 220),
        child: switch (state) {
          PhonePasswordChangeStarting() => _FlowNotice(
              key: const ValueKey('starting'),
              message: 'auth.own_phone_sending'.tr,
              busy: true,
              onBack: _leave,
            ),
          PhonePasswordChangeCodeSent() => VerifyScreen(
              // A resend is a new verification: a fresh screen picks up its
              // cooldown and any instant proof.
              key: ValueKey('code-${state.attempt}'),
              target: maskPhoneNumber(state.phoneNumber),
              autoVerify: state.verifiedWithoutCode,
              automaticProofAvailable: cubit.handle?.automaticProof,
              showVerifyButton: false,
              resendCooldown: state.resendAfter,
              onVerify: (code) async {
                final f = await cubit.verifyCode(code);
                return f == null
                    ? const VerifyResult.success()
                    : VerifyResult.failure(phonePasswordChangeMessage(f));
              },
              // The cubit moves the flow on; nothing to navigate to.
              onVerified: (_) {},
              onResend: () async {
                final f = await cubit.start();
                if (f == null) return const ResendResult.sent();
                return ResendResult.failure(
                  phonePasswordChangeMessage(f),
                  cooldown: isRateLimitFailure(f) ? _retryAfter(f) : null,
                );
              },
              onBackToLogin: _leave,
            ),
          PhonePasswordChangeEnteringPassword(:final policy) =>
            CreateNewPasswordScreen(
              key: const ValueKey('password'),
              policy: policy,
              submitLabel: 'auth.change_password_button'.tr,
              onSubmit: (newPassword) async {
                final f = await cubit.submitNewPassword(newPassword);
                return f == null
                    ? const ResetPasswordResult.success()
                    : ResetPasswordResult.failure(
                        phonePasswordChangeMessage(f));
              },
              onBack: _leave,
            ),
          PhonePasswordChangeSucceeded() => SuccessScreen(
              key: const ValueKey('done'),
              title: 'auth.own_password_changed_title'.tr,
              subtitle: 'auth.own_password_changed_subtitle'.tr,
              buttonLabel: 'common.done'.tr,
              showCoachMascot: true,
              onContinue: _leave,
            ),
          PhonePasswordChangeHalted(:final failure, :final canRestart) =>
            _FlowNotice(
              key: const ValueKey('halted'),
              message: phonePasswordChangeMessage(failure),
              actionLabel:
                  canRestart ? 'auth.own_phone_send_new_code'.tr : null,
              onAction: canRestart ? cubit.start : null,
              onBack: _leave,
            ),
        },
      ),
    );
  }

  /// The server's wait, or a minute when it named none.
  static Duration _retryAfter(Failure f) =>
      (f as ServerFailure).retryAfter ?? const Duration(seconds: 60);
}

/// The step before a code exists, and where the flow stops: the reset
/// steps' page, with one message and one action in the card.
class _FlowNotice extends StatelessWidget {
  const _FlowNotice({
    super.key,
    required this.message,
    required this.onBack,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AuthResetScaffold(
      onBack: onBack,
      mascotAsset: CoachMascot.phoneEntryAsset,
      title: 'auth.own_phone_title'.tr,
      subtitle: message,
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy)
            const Center(
              child: CircularProgressIndicator(
                color: AuthInk.accent,
              ),
            ),
          if (actionLabel != null)
            SignInButton(
              label: actionLabel!,
              iconTrailing: true,
              onPressed: onAction,
            ),
          if (!busy && actionLabel == null)
            SignInButton(
              label: 'common.back'.tr,
              iconTrailing: true,
              onPressed: onBack,
            ),
        ],
      ),
    );
  }
}
