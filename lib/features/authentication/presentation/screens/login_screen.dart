import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors_dark.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/version.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_remembered_phone.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_backdrop.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_form.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Sign-in for SteelForce.
///
/// The ISI building fills the top of the screen and fades into a dark base;
/// the brand mark sits on the photo, and the form is laid straight onto the
/// dark part — underline fields, one strong button, and a way back out as a
/// guest. No card: the photo *is* the surface.
///
/// Always dark, in both themes. The form sits on the photo's dark fade, so
/// light ink is the only ink that reads there.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onRequestAccess,
    this.onForgotPassword,
    this.getRememberedPhone,
  });

  /// Reads the number "Remember me" kept from the last sign-in, to pre-fill
  /// the phone field. Null: nothing is pre-filled.
  final GetRememberedPhone? getRememberedPhone;

  final VoidCallback? onRequestAccess;
  final VoidCallback? onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneKey = GlobalKey<PhoneNumberFieldState>();
  final _password = TextEditingController();

  /// "Remember me". Starts ticked when a number was remembered last time, so
  /// signing in again keeps it.
  bool _rememberPhone = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedPhone();
  }

  Future<void> _loadRememberedPhone() async {
    final get = widget.getRememberedPhone;
    if (get == null) return;
    final phone = (await get(const NoParams()))
        .when(success: (p) => p, failure: (_) => null);
    if (!mounted || phone == null || phone.isEmpty) return;
    _phoneKey.currentState?.prefill(phone);
    setState(() => _rememberPhone = true);
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final formOk = _formKey.currentState?.validate() ?? false;
    final phoneOk = _phoneKey.currentState?.validate() ?? false;
    if (!formOk || !phoneOk) return;

    // Single request. Sign-in is phone + password and nothing else: on
    // success `/auth/login` returns the token pair directly and the listener
    // below lands the rep on the shell.
    //
    // The one-time code is **not** part of signing in any more. It now guards
    // password *reset* only — the flow where a code in hand is the sole proof
    // of identity, because the password by definition cannot be. Requiring it
    // here as well charged every rep a second step, dozens of times a day, for
    // a factor that added nothing the password had not already established.
    context.read<AuthBloc>().add(
          LoginSubmittedEvent(
            identifier: _phoneKey.currentState!.value,
            password: _password.text,
            rememberPhone: _rememberPhone,
          ),
        );
  }

  /// Demo builds only: types the demo account in, so a presenter does not
  /// have to remember it.
  void _fillDemoAccount() {
    _phoneKey.currentState?.replace(DemoSeed.signInPhone);
    _password.text = DemoSeed.signInPassword;
  }

  /// Back to wherever sign-in was asked for — or, when this is the first
  /// screen (after a password reset), to the guest home.
  void _continueAsGuest() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushNamedAndRemoveUntil(Static.main, (route) => false);
    }
  }

  /// The dark base the photo fades into, in both themes.
  static const _base = AppColorsDark.background;

  @override
  Widget build(BuildContext context) {
    // Read through the shared extension rather than MediaQuery directly. It
    // uses `viewInsetsOf`, so this screen rebuilds as the keyboard animates
    // but not when unrelated metrics change — core/device/device_insets.dart.
    final insets = context.deviceInsets;
    final keyboard = insets.keyboard;
    final keyboardOpen = insets.isKeyboardOpen;
    final screen = MediaQuery.sizeOf(context);

    final maxFormWidth = context.responsive(
      compact: 420.0,
      medium: 480.0,
      expanded: 520.0,
    );

    return BlocListener<AuthBloc, AuthState>(
      // Sign-in is a single request, so success is the only outcome to route
      // on: the shell, or the change-password screen after a temporary
      // password.
      listenWhen: (prev, curr) => curr is AuthenticatedState,
      listener: (context, state) {
        if (!context.mounted) return;
        // A temporary password must be replaced before the shell. The
        // password just typed goes along so the rep is not asked for it again.
        if (state is AuthenticatedState && state.passwordChangeRequired) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Static.changeTemporaryPassword,
            (route) => false,
            arguments: _password.text,
          );
          return;
        }
        // Straight to the shell, clearing the stack: there is nothing behind a
        // completed sign-in worth backing into.
        Navigator.of(context)
            .pushNamedAndRemoveUntil(Static.main, (route) => false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Dark status-bar icons: the top of the screen is the light wash
        // behind the navy mark.
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          // Deliberately false, and the content layer below compensates.
          // Letting the Scaffold resize would shrink the whole body — including
          // the photo and its fade — so the backdrop would visibly squash every
          // time the keyboard opened.
          resizeToAvoidBottomInset: false,
          backgroundColor: _base,
          body: GestureDetector(
            // Tap any gap to put the keyboard away. `translucent` so the
            // fields, the reveal toggle, the forgot-password link and the
            // buttons all still win their own taps.
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                // The photo covers the top of the screen only; below it is
                // the plain dark base the form sits on.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: screen.height * 0.72,
                  child: LoginPhoto(showBlur: !keyboardOpen),
                ),
                const Positioned.fill(child: LoginBackdropWash()),
                // `SafeArea` first, then the keyboard padding — the whole
                // keyboard fix. Because the Scaffold does not resize, the
                // scrollable's viewport would otherwise extend behind the
                // keyboard, and Flutter's "scroll the focused field into view"
                // would do nothing because the field would already count as
                // visible. Ending the viewport above the keyboard fixes both.
                //
                // Plain `Padding`, not `AnimatedPadding` — the platform
                // reports `viewInsets` frame by frame as the keyboard slides,
                // so this tracks its edge exactly.
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: keyboard),
                    child: Column(
                      children: [
                        // The mark gives up its space while the keyboard is
                        // open — see [LoginBrand].
                        AnimatedSize(
                          duration: AppDurations.fast,
                          curve: AppCurves.standard,
                          child: keyboardOpen
                              ? const SizedBox(width: double.infinity)
                              : const LoginBrand(),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) => SingleChildScrollView(
                              // Dragging over the form dismisses the keyboard
                              // — the reliable one-handed escape for a rep
                              // holding the phone in a warehouse aisle.
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(minHeight: box.maxHeight),
                                // Bottom-anchored: the form sits on the dark
                                // part of the screen, under the photo.
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: maxFormWidth),
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        context.pagePadding + context.rw(8),
                                        context.rh(16),
                                        context.pagePadding + context.rw(8),
                                        context.rh(12),
                                      ),
                                      child: LoginForm(
                                        formKey: _formKey,
                                        phoneKey: _phoneKey,
                                        password: _password,
                                        rememberPhone: _rememberPhone,
                                        onRememberPhoneChanged: (v) =>
                                            setState(() => _rememberPhone = v),
                                        onSubmit: _submit,
                                        onContinueAsGuest: _continueAsGuest,
                                        // TODO(release-gate): demo-only hint.
                                        onFillDemoAccount:
                                            DataSourceMode.useMocks
                                                ? _fillDemoAccount
                                                : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The footer is the first thing to give up its space
                        // when the keyboard takes two thirds of a small
                        // screen. It carries no action, so collapsing it costs
                        // the user nothing.
                        AnimatedSize(
                          duration: AppDurations.fast,
                          curve: AppCurves.standard,
                          child: keyboardOpen
                              ? const SizedBox(width: double.infinity)
                              : const VersionFooter(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
