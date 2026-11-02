import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';

/// Localized display names for my_visits domain enums.
///
/// The domain keeps its English `label` getters (domain code imports no
/// localization); widgets render these instead.
extension VisitStatusLabel on VisitStatus {
  String get localizedLabel => switch (this) {
        VisitStatus.pending => 'my_visits.status.pending'.tr,
        VisitStatus.enRoute => 'my_visits.status.en_route'.tr,
        VisitStatus.arrived => 'my_visits.status.arrived'.tr,
        VisitStatus.checkedIn => 'my_visits.status.checked_in'.tr,
        VisitStatus.checkedOut => 'my_visits.status.completed'.tr,
        VisitStatus.missed => 'my_visits.status.missed'.tr,
      };
}

extension TerritoryTypeLabel on TerritoryType {
  String get localizedLabel => switch (this) {
        TerritoryType.urban => 'my_visits.territory.urban'.tr,
        TerritoryType.suburban => 'my_visits.territory.suburban'.tr,
        TerritoryType.industrial => 'my_visits.territory.industrial'.tr,
        TerritoryType.rural => 'my_visits.territory.rural'.tr,
      };
}

/// Translates the check-in refusal and warning sentences produced in English
/// by `FraudDetectionService` and `ActiveRouteBloc`.
///
/// Those sentences also travel to the server inside fraud flags, where they
/// must stay English, so the state keeps them as-is and only the widgets that
/// display them run them through here. Several blocked reasons may arrive
/// joined into one string, so each known sentence is replaced in place; any
/// text that is not recognised is returned unchanged.
String localizeCheckInMessage(String message) {
  var out = message;
  for (final rule in _checkInMessageRules) {
    out = out.replaceAllMapped(rule.$1, rule.$2);
  }
  return out;
}

final List<(RegExp, String Function(Match))> _checkInMessageRules = [
  (
    RegExp(r"You're outside the depot's geofence\."),
    (_) => 'my_visits.check_in_messages.outside_geofence'.tr,
  ),
  (
    RegExp(r'GPS accuracy too low \(±(\d+)m\) — move to open sky and retry\.'),
    (m) => 'my_visits.check_in_messages.low_accuracy'
        .trParams({'accuracy': m.group(1)}),
  ),
  (
    RegExp(r'Mock/fake location detected\.'),
    (_) => 'my_visits.check_in_messages.mock_location'.tr,
  ),
  (
    RegExp(r'Simulated location detected \(allowed in this build\)\.'),
    (_) => 'my_visits.check_in_messages.simulated_location'.tr,
  ),
  (
    RegExp(r'Disable your VPN to check in\.'),
    (_) => 'my_visits.check_in_messages.disable_vpn'.tr,
  ),
  (
    RegExp(
        r'VPN or proxy detected — location verification may be unreliable\.'),
    (_) => 'my_visits.check_in_messages.vpn_warning'.tr,
  ),
  (
    RegExp(r'No GPS fix yet — this check-in is recorded as unverified\.'),
    (_) => 'my_visits.check_in_messages.no_fix_unverified'.tr,
  ),
  (
    RegExp(
        r'This depot has no recorded location — the geofence could not be checked\.'),
    (_) => 'my_visits.check_in_messages.no_depot_location'.tr,
  ),
  (
    RegExp(r'No stop selected — go back and open the stop again\.'),
    (_) => 'my_visits.check_in_messages.no_stop_selected'.tr,
  ),
  (
    RegExp(r'^Checked in without location verification\. Reason: (.*)$',
        dotAll: true),
    (m) => 'my_visits.check_in_messages.unverified_with_reason'
        .trParams({'reason': m.group(1)}),
  ),
  (
    RegExp(r'^Checked in outside the geofence\. Reason: (.*)$', dotAll: true),
    (m) => 'my_visits.check_in_messages.outside_with_reason'
        .trParams({'reason': m.group(1)}),
  ),
];
