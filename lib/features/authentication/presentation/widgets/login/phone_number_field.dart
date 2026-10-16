import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/vibe_field.dart';
import 'package:phone_form_field/phone_form_field.dart';

/// The sign-in identifier for the field sales app: a phone number with a
/// country selector.
///
/// This app uses the **phone + password + OTP** flow. Employee ID / e-mail
/// sign-in exists on the same backend but is the admin-portal and back-office
/// route, so it is deliberately not offered here — a rep has one way in.
///
/// ## What is sent
///
/// The composed international form, `+855…`, which the integration guide lists
/// among the accepted spellings: `012345201`, `012 345 201`, `012-345-201` and
/// `+855 12 345 201` all resolve to the same account, because the server
/// matches on digits.
///
/// The country selector is what makes that composition honest rather than a
/// guess — a rep typing `012345201` means Cambodia, and picking the dial code
/// explicitly beats inferring it. Nothing is stripped or reformatted beyond
/// prefixing the dial code the user themselves selected.
///
/// Defaults to [IsoCode.KH]; the field force is Cambodian and making them pick
/// their own country on every sign-in would be friction with no payoff.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    this.defaultCountry = IsoCode.KH,
    this.textInputAction,
    this.required = true,
    this.underline = false,
  });

  /// Underline look with light ink, for a dark photo — see
  /// [lineFieldDecoration].
  final bool underline;

  final IsoCode defaultCountry;
  final TextInputAction? textInputAction;
  final bool required;

  @override
  State<PhoneNumberField> createState() => PhoneNumberFieldState();
}

class PhoneNumberFieldState extends State<PhoneNumberField> {
  final _fieldKey = GlobalKey<FormFieldState<PhoneNumber>>();

  late final PhoneController _controller = PhoneController(
    initialValue: PhoneNumber(isoCode: widget.defaultCountry, nsn: ''),
  );

  /// `+855…`. Empty when nothing has been typed, so the caller's validation
  /// runs before anything is sent.
  String get value {
    final phone = _controller.value;
    if (phone.nsn.isEmpty) return '';
    return '+${phone.countryCode}${phone.nsn}';
  }

  bool validate() => _fieldKey.currentState?.validate() ?? false;

  /// Fills in a remembered `+855…` number — unless the user has already
  /// started typing, which always wins over a value that arrived late.
  void prefill(String international) {
    if (_controller.value.nsn.isNotEmpty) return;
    try {
      _controller.value = PhoneNumber.parse(international);
    } catch (_) {
      // Unparseable: leave the field empty rather than half-filled.
    }
  }

  /// Replaces whatever is typed with the national number [nsn] in the
  /// default country. Unlike [prefill], an explicit request from the user.
  void replace(String nsn) {
    _controller.value = PhoneNumber(isoCode: widget.defaultCountry, nsn: nsn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Deliberately only a presence check.
  ///
  /// `PhoneValidator.validMobile` is tempting and wrong here: it would reject
  /// number ranges the server accepts, and the guide is explicit that the
  /// client must not impose a format. The server is the only thing that knows
  /// which numbers belong to ISI staff. This exists solely so an empty submit
  /// does not spend one of the ten sensitive-endpoint requests per five
  /// minutes.
  String? _validator(PhoneNumber? phone) {
    if (phone == null || phone.nsn.trim().isEmpty) {
      return widget.required ? 'auth.phone_required'.tr : null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final underline = widget.underline;
    final textStyle = TextStyle(
      color: underline ? Colors.white : scheme.onSurface,
      fontSize: context.rsp(underline ? 16 : 15),
      // Khmer stacks diacritics above and below the baseline; without this the
      // label clips in the border gap. See AppTypography.compactLineHeight.
      height: AppTypography.compactLineHeight,
    );

    // No nested blur — see [VibeField] for why. `GlassCard` blurs the panel
    // this sits on; a second filter here was invisible, expensive, and the
    // cause of both the clipped label and the per-frame
    // `!semantics.parentDataDirty` assertions.
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.22);

    return PhoneFormField(
      key: _fieldKey,
      controller: _controller,
      textInputAction: widget.textInputAction,
      style: textStyle,
      cursorColor: underline ? Colors.white : scheme.secondary,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autofillHints: const [AutofillHints.telephoneNumber],
      countrySelectorNavigator: const CountrySelectorNavigator.bottomSheet(),
      isCountrySelectionEnabled: true,
      // Persistent so the dial code stays visible while typing — a rep can see
      // at a glance that they are about to send a Cambodian number.
      isCountryButtonPersistent: true,
      countryButtonStyle: CountryButtonStyle(
        showDialCode: true,
        showIsoCode: false,
        showFlag: true,
        flagSize: context.rr(16),
        textStyle: textStyle,
      ),
      decoration: underline
          ? lineFieldDecoration(
              context,
              label: 'auth.phone_number'.tr,
              hint: 'auth.phone_hint'.tr,
              required: widget.required,
              // No icon: the country button (flag + dial code) leads the
              // field and does that job.
            )
          : vibeFieldDecoration(
              context,
              label: 'auth.phone_number'.tr,
              hint: 'auth.phone_hint'.tr,
              required: widget.required,
            ).copyWith(fillColor: fill),
      validator: _validator,
    );
  }
}
