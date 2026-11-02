import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/sign_in_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/reset/auth_reset_scaffold.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/vibe_field.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// Outcome of a password-reset submission, returned by
/// [CreateNewPasswordScreen.onSubmit].
class ResetPasswordResult {
  const ResetPasswordResult.success([this.message]) : isSuccess = true;
  const ResetPasswordResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String? message;
}

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({
    super.key,
    required this.onSubmit,
    this.onSuccess,
    this.onBack,
    this.policy,
    this.submitLabel,
  });

  final Future<ResetPasswordResult> Function(String newPassword) onSubmit;

  /// Password rules for reset. Null: only the
  /// basic length check applies, and the server has the final say.
  final PasswordPolicy? policy;
  final VoidCallback? onSuccess;
  final VoidCallback? onBack;

  /// Defaults to "Reset Password".
  final String? submitLabel;

  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  AuthVibeStatus _status = AuthVibeStatus.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _status = AuthVibeStatus.verifying;
      _errorMessage = null;
    });

    final result = await widget.onSubmit(_newPassword.text);

    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _status = AuthVibeStatus.success);
      widget.onSuccess?.call();
    } else {
      setState(() {
        _status = AuthVibeStatus.error;
        _errorMessage = result.message ?? 'auth.something_went_wrong'.tr;
      });
    }
  }

  String? _validateNew(String? value) {
    final v = value ?? '';
    final policy = widget.policy;
    if (policy == null) {
      return v.length < 6 ? 'auth.password_too_short'.tr : null;
    }
    return switch (policy.firstViolation(v)) {
      null => null,
      PasswordRule.minLength =>
        'auth.password_min_length'.trParams({'min': policy.minLength}),
      PasswordRule.maxLength =>
        'auth.password_max_length'.trParams({'max': policy.maxLength}),
      PasswordRule.uppercase => 'auth.password_needs_uppercase'.tr,
      PasswordRule.lowercase => 'auth.password_needs_lowercase'.tr,
      PasswordRule.number => 'auth.password_needs_number'.tr,
      PasswordRule.special => 'auth.password_needs_special'.tr,
      PasswordRule.distinctCharacters =>
        'auth.password_needs_distinct_characters'.tr,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AuthResetScaffold(
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      mascotAsset: CoachMascot.newPasswordAsset,
      title: 'auth.create_new_password_title'.tr,
      accentLastWord: true,
      subtitle: 'auth.create_new_password_subtitle'.tr,
      card: _form(),
    );
  }

  Widget _reveal(bool obscured, VoidCallback onToggle) => IconButton(
        tooltip: obscured ? 'auth.show_password'.tr : 'auth.hide_password'.tr,
        icon: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AuthInk.muted,
          size: context.rr(22),
        ),
        onPressed: onToggle,
      );

  Widget _form() {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VibeField(
              controller: _newPassword,
              label: 'auth.new_password'.tr,
              icon: Icons.lock_outline_rounded,
              obscure: _obscureNew,
              onPhoto: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              required: true,
              suffix: _reveal(_obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew)),
              validator: _validateNew,
            ),
            SizedBox(height: context.rh(14)),
            VibeField(
              controller: _confirmPassword,
              label: 'auth.confirm_new_password'.tr,
              icon: Icons.lock_reset_rounded,
              obscure: _obscureConfirm,
              onPhoto: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              required: true,
              onSubmitted: (_) => _submit(),
              suffix: _reveal(_obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm)),
              validator: (v) => v == _newPassword.text
                  ? null
                  : 'auth.passwords_dont_match'.tr,
            ),
            SizedBox(height: context.rh(20)),
            StatusPill(status: _status, message: _errorMessage, onDark: true),
            SignInButton(
              label: widget.submitLabel ?? 'auth.reset_password_button'.tr,
              iconTrailing: true,
              loading: _status == AuthVibeStatus.verifying,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
