import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_event.dart';
import 'package:steelforce/features/authentication/presentation/bloc/auth_state.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_form_card.dart';
import 'package:steelforce/features/authentication/domain/usecases/get_remembered_phone.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_background.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_entrance.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_security_footer.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/login_welcome_section.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/phone_number_field.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/sign_in_button.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/status_pill.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/vibe_field.dart';
import 'package:steelforce/routes/app_routes.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// Sign-in for SteelForce.
///
/// The brand chevron fills the screen, with a lit arc along the bottom
/// ([LoginBackground]). The light SteelForce lockup sits top-left, the
/// "Grow Together / Stronger" headline above the form, and the form itself
/// in a floating glass card: phone, password, remember-me and forgot, one
/// lit Sign In and a quiet way out as a guest. The security line with the
/// build sits under the card, on the backdrop.
///
/// Dark in both themes — it is the brand backdrop. The theme shows in the
/// primary action: Apex Blue in light, the lifted dark-theme primary in dark.
///
/// The content is bottom-anchored and scrolls: on a short screen, in Khmer,
/// or with an error showing it rides up onto the plain pattern, which is
/// already dark enough for white text. While the keyboard is open the logo
/// and headline give up their space so Sign In stays reachable.
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneKey = GlobalKey<PhoneNumberFieldState>();
  final _password = TextEditingController();
  bool _obscure = true;

  /// "Remember me". Starts ticked when a number was remembered last time, so
  /// signing in again keeps it.
  bool _rememberPhone = false;

  /// The whole entrance: background → logo → headline → fields → button →
  /// guest and footer, each over its own slice of this one controller.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedPhone();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    // Reduced motion: everything simply present.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
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
    _entrance.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    // The button is disabled while a request is in flight; Enter on the
    // keyboard is not, so guard here too — one sign-in at a time.
    if (context.read<AuthBloc>().state is AuthLoadingState) return;

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

  /// One beat of the entrance — see [LoginEntrance].
  Widget _beat(double begin, double end, Widget child) =>
      LoginEntrance(parent: _entrance, begin: begin, end: end, child: child);

  @override
  Widget build(BuildContext context) {
    // Read through the shared extension rather than MediaQuery directly. It
    // uses `viewInsetsOf`, so this screen rebuilds as the keyboard animates
    // but not when unrelated metrics change.
    final insets = context.deviceInsets;
    final keyboard = insets.keyboard;
    final keyboardOpen = insets.isKeyboardOpen;
    final screen = MediaQuery.sizeOf(context);
    // iPhone SE and smaller: a tighter headline so the form keeps its room.
    final dense = screen.height < 720;

    final isLandscape = screen.width > screen.height;
    final isTabletLandscape = screen.width >= 960 && isLandscape;
    final isTabletPortrait =
        (screen.shortestSide >= 600 || !context.isCompactWindow) &&
            !isLandscape;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final maxContentWidth = context.responsive(
      compact: 480.0,
      medium: 480.0,
      expanded: 520.0,
    );
    final gutter = context.pagePadding + context.rw(8);

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
        // Dark status-bar icons: the top of the screen is the white pattern.
        value: SystemUiOverlayStyle.dark,
        child: AuthLightTheme(
            child: Scaffold(
          // Deliberately false, and the content layer below compensates.
          // Letting the Scaffold resize would shrink the whole body — including
          // the backdrop — so the pattern would visibly squash every time the
          // keyboard opened.
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.white,
          body: GestureDetector(
            // Tap any gap to put the keyboard away. `translucent` so the
            // fields and buttons still win their own taps.
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: LoginBackground(
                    opacity: CurvedAnimation(
                      parent: _entrance,
                      curve: const Interval(0, 0.35, curve: Curves.easeOut),
                    ),
                  ),
                ),
                if (isTabletLandscape)
                  _buildTabletLandscape(
                      gutter, keyboardOpen, keyboard, bottomInset)
                else if (isTabletPortrait)
                  _buildTabletPortrait(
                    gutter,
                    keyboardOpen,
                    keyboard,
                    bottomInset,
                    dense,
                  )
                else
                  _buildPhoneLayout(
                    maxContentWidth,
                    gutter,
                    keyboardOpen,
                    keyboard,
                    dense,
                  ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildTabletLandscape(
    double gutter,
    bool keyboardOpen,
    double keyboard,
    double bottomInset,
  ) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(
              horizontal: context.pagePadding * 1.5,
              vertical: context.rh(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: context.rw(32)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _beat(0.1, 0.45, const LoginBrandHeader()),
                          SizedBox(height: context.rh(28)),
                          _beat(
                            0.22,
                            0.6,
                            const LoginWelcomeSection(dense: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthFormCard(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rw(24),
                              vertical: context.rh(24),
                            ),
                            child: _form(false),
                          ),
                          SizedBox(height: context.rh(18)),
                          _beat(0.7, 1, const LoginSecurityFooter()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletPortrait(
    double gutter,
    bool keyboardOpen,
    double keyboard,
    double bottomInset,
    bool dense,
  ) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              gutter,
              context.rh(32),
              gutter,
              bottomInset + context.rh(32),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _beat(
                      0.1,
                      0.45,
                      const LoginBrandHeader(center: true),
                    ),
                  ),
                  SizedBox(height: context.rh(28)),
                  _beat(0.22, 0.6, LoginWelcomeSection(dense: dense)),
                  SizedBox(height: context.rh(24)),
                  AuthFormCard(
                    padding: EdgeInsets.fromLTRB(
                      context.rw(24),
                      context.rh(dense ? 20 : 26),
                      context.rw(24),
                      context.rh(dense ? 8 : 14),
                    ),
                    child: _form(dense),
                  ),
                  SizedBox(height: context.rh(dense ? 16 : 22)),
                  _beat(0.7, 1, const LoginSecurityFooter()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(
    double maxContentWidth,
    double gutter,
    bool keyboardOpen,
    double keyboard,
    bool dense,
  ) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          children: [
            AnimatedSize(
              duration: AppDurations.medium,
              curve: AppCurves.standard,
              child: keyboardOpen
                  ? const SizedBox(width: double.infinity)
                  : _column(
                      maxContentWidth,
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          context.rh(dense ? 12 : 24),
                          gutter,
                          0,
                        ),
                        child: _beat(
                          0.1,
                          0.45,
                          const LoginBrandHeader(),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _column(
                        maxContentWidth,
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSize(
                              duration: AppDurations.medium,
                              curve: AppCurves.standard,
                              child: keyboardOpen
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        gutter,
                                        context.rh(20),
                                        gutter,
                                        context.rh(dense ? 18 : 28),
                                      ),
                                      child: _beat(
                                        0.22,
                                        0.6,
                                        LoginWelcomeSection(dense: dense),
                                      ),
                                    ),
                            ),
                            _panel(gutter, keyboardOpen, dense),
                          ],
                        ),
                      ),
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

  /// Centres [child] in a column no wider than [maxWidth] — on a tablet the
  /// form keeps phone proportions instead of stretching edge to edge.
  Widget _column(double maxWidth, Widget child) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );

  /// The floating glass card the form sits in, with the security footer
  /// beneath it on the backdrop. The card is translucent navy with a lit
  /// rim, so the pattern shows faintly through it.
  Widget _panel(double gutter, bool keyboardOpen, bool dense) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Narrower margins than the headline's gutter: the card reads as a
    // surface the text above sits over, as in the artwork.
    final margin = context.rw(12);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: AuthFormCard(
            padding: EdgeInsets.fromLTRB(
              gutter - margin,
              context.rh(dense ? 20 : 26),
              gutter - margin,
              context.rh(dense ? 8 : 14),
            ),
            child: _form(dense),
          ),
        ),
        // The footer carries no action; it is the first thing to go when
        // the keyboard needs the room.
        AnimatedSize(
          duration: AppDurations.medium,
          curve: AppCurves.standard,
          child: keyboardOpen
              ? SizedBox(width: double.infinity, height: context.rh(12))
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    context.rh(dense ? 14 : 22),
                    gutter,
                    // Clear of the home indicator; the keyboard padding
                    // does that job while it is open.
                    bottomInset + context.rh(dense ? 10 : 18),
                  ),
                  child: _beat(0.7, 1, const LoginSecurityFooter()),
                ),
        ),
      ],
    );
  }

  Widget _form(bool dense) {
    final gap = context.rh(dense ? 12 : 16);

    // One autofill context for the phone + password pair, so iOS Keychain and
    // Android Autofill can fill both from a single saved credential and offer
    // to save the pair afterwards.
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The identifier travels to `/mobile/auth/login` as `employeeId`,
            // which the server resolves.
            _beat(
              0.35,
              0.7,
              PhoneNumberField(
                key: _phoneKey,
                required: true,
                onPhoto: true,
                textInputAction: TextInputAction.next,
              ),
            ),
            SizedBox(height: gap),
            _beat(
              0.42,
              0.77,
              VibeField(
                controller: _password,
                label: 'auth.password'.tr,
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                onPhoto: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                required: true,
                onSubmitted: (_) => _submit(),
                suffix: _RevealToggle(
                  obscured: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'auth.password_too_short'.tr
                    : null,
              ),
            ),
            SizedBox(height: context.rh(6)),
            _beat(
              0.48,
              0.82,
              Row(
                children: [
                  Expanded(
                    child: _RememberMe(
                      value: _rememberPhone,
                      onChanged: (v) => setState(() => _rememberPhone = v),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Static.forgotPassword),
                    style: TextButton.styleFrom(
                      foregroundColor: AuthInk.accent,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.symmetric(horizontal: context.rw(8)),
                    ),
                    child: Text(
                      'auth.forgot_short'.tr,
                      semanticsLabel: 'auth.forgot_password'.tr,
                      style: TextStyle(
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.rh(10)),
            _beat(
              0.52,
              0.86,
              BlocBuilder<AuthBloc, AuthState>(
                buildWhen: (prev, curr) =>
                    prev.runtimeType != curr.runtimeType ||
                    (curr is AuthFailureState && prev != curr),
                builder: (context, state) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Failures only: without the message a wrong password
                    // simply stops the spinner and leaves the rep guessing.
                    // It grows in rather than shoving the button down.
                    AnimatedSize(
                      duration: AppDurations.medium,
                      curve: AppCurves.standard,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: AppDurations.medium,
                        child: state is AuthFailureState
                            ? StatusPill(
                                key: ValueKey(state.message),
                                status: AuthVibeStatus.error,
                                message: state.message,
                                onDark: true,
                              )
                            : const SizedBox(
                                key: ValueKey('none'),
                                width: double.infinity,
                              ),
                      ),
                    ),
                    SignInButton(
                      label: 'auth.login_btn'.tr,
                      loading: state is AuthLoadingState,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.rh(dense ? 4 : 10)),
            _beat(0.62, 1, _GuestAccess(onPressed: _continueAsGuest)),
          ],
        ),
      ),
    );
  }
}

/// Show / hide password, behind a hairline divider, with the eye crossfading
/// between its two states.
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.obscured, required this.onToggle});

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = AuthInk.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 1,
          height: context.rr(24),
          color: AuthInk.hairline,
        ),
        Padding(
          padding: EdgeInsetsDirectional.only(end: context.rw(6)),
          child: IconButton(
            tooltip:
                obscured ? 'auth.show_password'.tr : 'auth.hide_password'.tr,
            onPressed: onToggle,
            icon: AnimatedSwitcher(
              duration: AppDurations.medium,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: RotationTransition(
                  turns: Tween(begin: -0.08, end: 0.0).animate(a),
                  child: child,
                ),
              ),
              child: Icon(
                obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                key: ValueKey(obscured),
                color: muted,
                size: context.rr(22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Remember me": keeps the phone number — never the password — for the
/// next sign-in. The whole row is the tap target, not just the box.
class _RememberMe extends StatelessWidget {
  const _RememberMe({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  activeColor: AppColors.signalBlue,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: AuthInk.fieldBorder,
                    width: 1.5,
                  ),
                ),
              ),
              SizedBox(width: context.rw(12)),
              Flexible(
                child: Text(
                  'auth.remember_me'.tr,
                  style: TextStyle(
                    color: AuthInk.muted,
                    fontSize: context.rsp(15),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Continue as Guest", between two hairlines — present, never competing with
/// Sign In. Guest mode is the shell's own; this only leaves the screen.
class _GuestAccess extends StatelessWidget {
  const _GuestAccess({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: AuthInk.hairline, height: 1),
    );
    return Row(
      children: [
        line,
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AuthInk.accent,
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.symmetric(horizontal: context.rw(16)),
          ),
          child: Text(
            'auth.continue_as_guest'.tr,
            style: TextStyle(
              fontSize: context.rsp(15),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
