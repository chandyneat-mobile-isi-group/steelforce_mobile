import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/shared/widgets/aurora_background.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/vibe_field.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

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
  });

  final Future<ResetPasswordResult> Function(String newPassword) onSubmit;

  /// The server's rules, from `forgot-password/verify-otp`. Null: only the
  /// basic length check applies, and the server has the final say.
  final PasswordPolicy? policy;
  final VoidCallback? onSuccess;
  final VoidCallback? onBack;

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
    };
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic max-width for tablet viewports while keeping column layout
    final maxCardWidth = context.responsive(
      compact: 420.0,
      medium: 520.0,
      expanded: 580.0,
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
                  onPressed:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      // FIXED: Dynamic EdgeInsets using context.pagePadding
                      padding: EdgeInsets.all(context.pagePadding),
                      child: ConstrainedBox(
                        // FIXED: Replaced static 420 constraint with responsive scaling
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.password_outlined,
                                  size: context.rr(40),
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                SizedBox(height: context.rh(18)),
                                Text(
                                  'auth.create_new_password_title'.tr,
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
                                  'auth.create_new_password_subtitle'.tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.appColors.textSecondary,
                                      fontSize: context.rsp(15)),
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VibeField(
            controller: _newPassword,
            label: 'auth.new_password'.tr,
            icon: Icons.lock_outline,
            obscure: _obscureNew,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            required: true,
            suffix: IconButton(
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: context.appColors.textSecondary,
                size: context.rr(20),
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            validator: _validateNew,
          ),
          SizedBox(height: context.rh(14)),
          VibeField(
            controller: _confirmPassword,
            label: 'auth.confirm_new_password'.tr,
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            required: true,
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: context.appColors.textSecondary,
                size: context.rr(20),
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) =>
                v == _newPassword.text ? null : 'auth.passwords_dont_match'.tr,
          ),
          SizedBox(height: context.rh(20)),
          StatusPill(status: _status, message: _errorMessage),
          GradientButton(
            label: 'auth.reset_password_button'.tr,
            loading: _status == AuthVibeStatus.verifying,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // FIXED: Converted static padding to relative responsive constraints
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
