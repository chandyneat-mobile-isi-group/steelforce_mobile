/// Which kind of depot the registration wizard is recording, picked on step 1.
///
/// One wizard registers both. The choice is held on the draft, saved with it,
/// and sent as `depotType` (`DEPOT` / `NON_DEPOT`) to `POST /mobile/depots`.
enum DepotRegistrationType {
  depot('depot', 'add_depot.registration_type.depot'),
  nonBp('non_bp', 'add_depot.registration_type.non_bp');

  const DepotRegistrationType(this.storageValue, this.labelKey);

  /// The value in the locally saved draft. Stable: renaming it would strand
  /// drafts already on a device.
  final String storageValue;
  final String labelKey;

  /// Unknown or missing values read as [depot], the only kind drafts saved
  /// before this choice existed can be.
  static DepotRegistrationType fromStorage(Object? raw) =>
      values.where((t) => t.storageValue == raw).firstOrNull ?? depot;
}
