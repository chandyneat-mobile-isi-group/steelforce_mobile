import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a destination to the device's map app with driving directions already
/// routed, so a rep gets guidance without retyping the shop's address.
///
/// **Deliberately does not import `dart:io`.** This app also builds for web
/// (GitHub Pages), and `dart:io` does not exist there — importing it would
/// break that target at compile time. `kIsWeb` + `defaultTargetPlatform` from
/// `foundation` give the same branch web-safely.
///
/// Candidates are tried most-specific first:
///
///  * **Android** — `google.navigation:` is the only scheme that begins
///    turn-by-turn guidance immediately instead of showing a route preview.
///  * **iOS** — Google Maps when the rep has it, so the experience matches
///    Android; Apple Maps otherwise, which is guaranteed to be present. Note
///    neither iOS scheme can auto-start guidance — Apple does not expose that
///    to third-party apps — so both land on the route preview with the
///    destination and driving mode already filled in, one tap from "Go".
///  * **Anything else** — the universal `google.com/maps/dir` HTTPS URL, which
///    also covers the web build and desktop.
///
/// Returns false when nothing could handle the request, so the caller can tell
/// the user rather than appear to do nothing.
Future<bool> openDrivingDirections({
  required double latitude,
  required double longitude,
}) async {
  final destination = '$latitude,$longitude';

  final candidates = <Uri>[
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      Uri.parse('google.navigation:q=$destination&mode=d'),
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
      Uri.parse('comgooglemaps://?daddr=$destination&directionsmode=driving'),
      Uri.parse('https://maps.apple.com/?daddr=$destination&dirflg=d'),
    ],
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destination&travelmode=driving',
    ),
  ];

  for (final uri in candidates) {
    try {
      // `canLaunchUrl` on a custom scheme only answers truthfully when that
      // scheme is declared in LSApplicationQueriesSchemes (iOS) — see
      // ios/Runner/Info.plist, which lists `comgooglemaps` for this reason.
      if (!await canLaunchUrl(uri)) continue;
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (e) {
      // A refused scheme is the expected outcome when the app isn't installed,
      // so fall through to the next candidate rather than surfacing this.
      if (kDebugMode)
        debugPrint('[navigation] ${uri.scheme} could not be launched: $e');
    }
  }
  return false;
}
