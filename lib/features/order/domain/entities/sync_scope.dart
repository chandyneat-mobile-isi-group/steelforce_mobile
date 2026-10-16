import 'package:equatable/equatable.dart';
import 'package:steelforce/core/session/session_manager.dart';

/// Narrows what a sales rep's device actually needs to hold locally.
///
/// Sourced from [SessionManager] where the signed-in [User] carries the
/// data (rep id) and from sensible mock defaults for the fields the current
/// `User` entity doesn't model yet (territory/warehouse/business unit/pricing
/// group) — this is the configurable extension point once auth grows those
/// fields; deliberately not added to `User` here since that's an unrelated
/// feature's entity.
class SyncScope extends Equatable {
  const SyncScope({
    required this.repId,
    required this.territory,
    required this.warehouseCodes,
    required this.businessUnit,
    required this.pricingGroup,
  });

  final String repId;
  final String territory;
  final List<String> warehouseCodes;
  final String businessUnit;
  final String pricingGroup;

  /// The current `User` entity has no territory/warehouse/business-unit/
  /// pricing-group fields yet, so this fills in a stable mock default keyed
  /// off the signed-in rep — swap this for real profile fields once auth
  /// grows them, with no other call site needing to change.
  factory SyncScope.forCurrentUser(SessionManager sessionManager) {
    final user = sessionManager.currentUser;
    return SyncScope(
      repId: user?.id ?? 'guest',
      territory: 'Phnom Penh',
      warehouseCodes: const ['WH-PP01', 'WH-PP02', 'WH-PP03'],
      businessUnit: 'Construction Steel',
      pricingGroup: 'STANDARD',
    );
  }

  bool matchesWarehouse(String warehouseCode) =>
      warehouseCodes.isEmpty || warehouseCodes.contains(warehouseCode);

  @override
  List<Object?> get props =>
      [repId, territory, warehouseCodes, businessUnit, pricingGroup];
}
