import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/authentication/presentation/screens/create_new_password_screen.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/vibe_field.dart';
import 'package:steelforce/shared/widgets/aurora_background.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';

/// Shown straight after a sign-in that used a temporary password
/// (`passwordChangeRequired` on the login response). The rep sets their own
/// password here before reaching the shell.
///
/// There is no back button: the only ways out are a successful change or
/// signing out. The temporary password the rep has just typed at sign-in is
/// handed over as [currentPassword] so they are not asked for it twice. On a
/// cold start nothing is carried over, so the screen asks for it.
class ChangeTemporaryPasswordScreen extends StatefulWidget {
  const ChangeTemporaryPasswordScreen({
    super.key,
    required this.onSubmit,
    required this.onSuccess,
    required this.onSignOut,
    this.currentPassword,
  });

  /// The temporary password from the sign-in form. Null: ask for it.
  final String? currentPassword;

  final Future<ResetPasswordResult> Function(
    String currentPassword,
    String newPassword,
  ) onSubmit;
  final VoidCallback onSuccess;
  final VoidCallback onSignOut;

  /// The documented server policy (`docs/feature/authentication/
  /// integration-guide.md`, "Password management"). The server re-checks it.
  static const minLength = 12;

  @override
  State<ChangeTemporaryPasswordScreen> createState() =>
      _ChangeTemporaryPasswordScreenState();
}

class _ChangeTemporaryPasswordScreenState
    extends State<ChangeTemporaryPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  AuthVibeStatus _status = AuthVibeStatus.idle;
  String? _errorMessage;

  bool get _asksForCurrent => widget.currentPassword == null;

  String get _currentValue => widget.currentPassword ?? _current.text;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_status == AuthVibeStatus.verifying) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _status = AuthVibeStatus.verifying;
      _errorMessage = null;
    });

    final result = await widget.onSubmit(_currentValue, _newPassword.text);

    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _status = AuthVibeStatus.success);
      widget.onSuccess();
    } else {
      setState(() {
        _status = AuthVibeStatus.error;
        _errorMessage = result.message ?? 'auth.something_went_wrong'.tr;
      });
    }
  }

  String? _validateNew(String? v) {
    if (v == null || v.length < ChangeTemporaryPasswordScreen.minLength) {
      return 'auth.change_password_too_short'.tr;
    }
    if (v == _currentValue) return 'auth.change_password_same_as_current'.tr;
    return null;
  }

  String? _validateConfirm(String? v) =>
      v == _newPassword.text ? null : 'auth.passwords_dont_match'.tr;

  @override
  Widget build(BuildContext context) {
    final maxCardWidth = context.responsive(
      compact: 420.0,
      medium: 520.0,
      expanded: 580.0,
    );
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      // A temporary password is not a finished sign-in. Backing out would
      // land on the shell with it still in force.
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            const Positioned.fill(child: AuroraBackground()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.pagePadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxCardWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.lock_reset_outlined,
                          size: context.rr(40),
                          color: scheme.secondary,
                        ),
                        SizedBox(height: context.rh(18)),
                        Text(
                          'auth.change_temp_password_title'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: context.rsp(26),
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: context.rh(8)),
                        Text(
                          'auth.change_temp_password_subtitle'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: context.rsp(15),
                          ),
                        ),
                        SizedBox(height: context.rh(24)),
                        GlassCard(child: _form()),
                        SizedBox(height: context.rh(12)),
                        TextButton(
                          onPressed: _status == AuthVibeStatus.verifying
                              ? null
                              : widget.onSignOut,
                          child: Text('auth.change_temp_password_sign_out'.tr),
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
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_asksForCurrent) ...[
              _PasswordField(
                controller: _current,
                label: 'auth.current_password'.tr,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v == null || v.isEmpty)
                    ? 'auth.password_required'.tr
                    : null,
              ),
              SizedBox(height: context.rh(14)),
            ],
            _PasswordField(
              controller: _newPassword,
              label: 'auth.new_password'.tr,
              autofillHints: const [AutofillHints.newPassword],
              validator: _validateNew,
            ),
            SizedBox(height: context.rh(14)),
            _PasswordField(
              controller: _confirmPassword,
              label: 'auth.confirm_new_password'.tr,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: _validateConfirm,
            ),
            SizedBox(height: context.rh(20)),
            StatusPill(status: _status, message: _errorMessage),
            GradientButton(
              label: 'auth.change_password_button'.tr,
              loading: _status == AuthVibeStatus.verifying,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// A [VibeField] with its own reveal toggle.
class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.autofillHints,
    required this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> autofillHints;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return VibeField(
      controller: widget.controller,
      label: widget.label,
      icon: Icons.lock_outline,
      obscure: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      required: true,
      onSubmitted: widget.onSubmitted,
      validator: widget.validator,
      suffix: IconButton(
        tooltip: _obscure ? 'auth.show_password'.tr : 'auth.hide_password'.tr,
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: context.appColors.textSecondary,
          size: context.rr(20),
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
