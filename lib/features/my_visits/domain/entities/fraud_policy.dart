import 'package:equatable/equatable.dart';

/// True in a release build.
///
/// The same constant Flutter's `kReleaseMode` is defined as, spelled out here
/// so this domain entity stays free of Flutter imports
/// (`.claude/rules/architecture.md` §1).
const bool kFraudPolicyReleaseBuild = bool.fromEnvironment('dart.vm.product');

/// Configurable enforcement rules — modular by design so business rules can
/// enable/disable/relax individual checks without touching
/// `FraudDetectionService`'s detection logic itself.
///
/// **Mock location is always blocked in a release build**, whatever the
/// constructor was given — see [blockOnMockLocation].
class FraudPolicy extends Equatable {
  const FraudPolicy({
    // TODO(release-gate): debug and profile builds tolerate a mock location
    // by default, because Android emulators always report
    // `Position.isMocked == true` for simulated GPS and a strict default would
    // make check-in untestable during development. A release build ignores
    // this and blocks (see `blockOnMockLocation`); nothing needs to replace it
    // before release, but it must never be widened to cover release.
    bool blockOnMockLocation = kFraudPolicyReleaseBuild,
    this.blockOnVpn = false,
    this.maxAccuracyMeters = 50,
    this.maxSpeedKmh = 150,
    this.allowReasonedCheckInOverride = true,
    this.minOverrideReasonLength = 10,
    this.isReleaseBuild = kFraudPolicyReleaseBuild,
  }) : _blockOnMockLocation = blockOnMockLocation;

  final bool _blockOnMockLocation;

  /// Whether this build is a release build. Defaults to the compile-time
  /// constant; exists as a parameter only so tests can exercise the release
  /// rule, which a `flutter test` VM (always debug) otherwise never reaches.
  final bool isReleaseBuild;

  /// Whether a mock/fake location provider refuses the check-in outright.
  ///
  /// Always true in a release build: a mocked position is a claim that the
  /// device is not telling the truth, and a shipped app must not accept it.
  /// Only a non-release build may relax it.
  bool get blockOnMockLocation => isReleaseBuild || _blockOnMockLocation;

  final bool blockOnVpn;

  /// The coarsest fix (reported accuracy radius, metres) a check-in accepts
  /// without a written reason.
  ///
  /// **50 m, was 30 m.** Indoors — which is where a check-in happens — a
  /// phone's fused Wi-Fi/cell fix typically reports ±20–60 m. At 30 m a rep
  /// standing inside the right shop was routinely refused as "accuracy too
  /// low". 50 m still sits well inside the 100 m check-in radius, so a fix
  /// accepted here cannot place a rep who is actually outside the area inside
  /// it by more than half the radius. Anything coarser still checks in — with
  /// a reason. Set back to 30 for a stricter territory.
  final double maxAccuracyMeters;
  final double maxSpeedKmh;

  /// Whether a rep may check in from outside the geofence, or on a fix too
  /// imprecise to judge, by giving a written reason.
  ///
  /// Exists because the geofence assumes two things a depot often breaks: that
  /// the shop's recorded pin is where the rep can stand, and that the handset
  /// can get a clean fix there. A yard entrance a hundred metres from the
  /// office pin, or a warehouse under a steel roof, fails both while the rep is
  /// demonstrably doing their job.
  ///
  /// **This never relaxes the integrity rules.** A mock location provider or a
  /// VPN cannot be reasoned past — those are claims about whether the device is
  /// telling the truth, and no free-text box should be able to answer them.
  /// Only the two location-derived rules are overridable.
  ///
  /// Turn it off for a territory where every stop is reliably geotagged and the
  /// override would just be a habit.
  final bool allowReasonedCheckInOverride;

  /// The shortest reason accepted. Long enough that "ok" and "." do not pass,
  /// short enough that a rep typing on a phone in a yard is not fighting it.
  final int minOverrideReasonLength;

  @override
  List<Object?> get props => [
        blockOnMockLocation,
        isReleaseBuild,
        blockOnVpn,
        maxAccuracyMeters,
        maxSpeedKmh,
        allowReasonedCheckInOverride,
        minOverrideReasonLength,
      ];
}
