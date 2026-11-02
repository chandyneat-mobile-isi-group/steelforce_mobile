/// Whether this device still holds steps of a visit the server lacks.
enum PlanSyncState {
  /// Nothing waiting — the visit is as the server reports it.
  synced,

  /// Steps saved offline, waiting to be sent.
  pending,

  /// The server refused a step; it and the steps after it wait for the rep.
  needsAttention,
}
