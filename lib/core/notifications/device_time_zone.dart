import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's **IANA** time zone, e.g. `Asia/Phnom_Penh`.
///
/// ## Why the abbreviation will not do
///
/// Dart core exposes only `DateTime.now().timeZoneName`, which yields `ICT` or
/// `+07` — and `DeviceIdentity._timeZone` already carries a note saying to swap
/// in `flutter_timezone` here if an exact IANA name is ever required. It is
/// required now: `docs/feature/notification/README.md` §4.2 makes this the
/// field the backend places quiet hours and digests against, because both are
/// **wall-clock facts** rather than instants. An abbreviation is not a zone —
/// it carries no DST rules and several are ambiguous across regions — so the
/// backend cannot resolve one and falls back to UTC. In Cambodia (UTC+7) that
/// turns a rep's 22:00 quiet window into one starting at 05:00 local, which
/// reads as the feature simply not working.
///
/// ## Failure returns null, not a guess
///
/// The platform channel can fail on an OEM build with a stripped zone database.
/// Null omits the field, and §4.2 documents the consequence — the backend
/// assumes UTC — which is at least a *known* wrong answer. Substituting a
/// plausible-looking zone would be a wrong answer nobody can detect.
Future<String?> readIanaTimeZone() async {
  try {
    // Returns the IANA identifier as a plain String in this plugin version.
    final name = (await FlutterTimezone.getLocalTimezone()).trim();
    return name.isEmpty ? null : name;
  } catch (_) {
    // Deliberately silent rather than logged: this is called on every
    // registration, which happens on every launch (§4.1), so a permanently
    // broken zone database would fill the log with a line nobody can act on.
    // The absent field is visible in the device registry, which is where a
    // support engineer would actually look.
    return null;
  }
}
