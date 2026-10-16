/// The depot lifecycle, as the API defines it.
///
/// **Branch on this; render `statusDisplay`.** The API returns two flat
/// fields — a stable `status` code and a `statusDisplay` label already
/// translated into the requested language. The code is what logic keys off;
/// the label changes with `Accept-Language`, so branching on it would make the
/// app behave differently in Khmer than in English.
enum DepotStatus {
  /// Newly registered in the field and not yet activated. **Cannot trade**
  /// until someone holding `depots.approve` activates it.
  draft('Draft'),
  pendingApproval('PendingApproval'),
  active('Active'),
  suspended('Suspended'),

  /// Terminal. A closed depot cannot be edited at all — an attempt returns
  /// `Depot.Closed` (422).
  closed('Closed'),

  // ── Legacy local-only values ──────────────────────────────────────
  // Not part of the API lifecycle. These predate the real integration and
  // survive only so rows written by the mock data source, and any already
  // persisted in the encrypted database, still deserialise. Nothing the server
  // sends will ever map here.
  dormant('Dormant'),
  creditHold('Credit Hold');

  const DepotStatus(this.apiValue);

  /// The exact string the API uses, which is also what a `status` query
  /// parameter must be given.
  final String apiValue;

  /// Retained for existing call sites that render a bare English label.
  /// Prefer a localised label keyed off the enum, or the server's
  /// `statusDisplay`.
  String get label => apiValue;

  /// The values a user may filter by. Excludes the legacy pair above, which
  /// would send a `status` the server does not recognise.
  static const List<DepotStatus> selectable = [
    draft,
    pendingApproval,
    active,
    suspended,
    closed,
  ];

  /// Parses the API's `status` field.
  ///
  /// Unknown values fall back to [draft] rather than throwing: a server that
  /// adds a lifecycle state must not crash a build that predates it, and
  /// `draft` is the safe default because it is the one state that cannot
  /// trade. Erring toward "cannot trade" is recoverable; erring toward
  /// "active" would let a rep write an order against a depot the server
  /// will reject.
  static DepotStatus fromApi(String? raw) {
    if (raw == null || raw.isEmpty) return draft;
    for (final value in values) {
      if (value.apiValue.toLowerCase() == raw.toLowerCase() ||
          value.name.toLowerCase() == raw.toLowerCase()) {
        return value;
      }
    }
    return draft;
  }

  /// Whether this depot may have orders written against it.
  ///
  /// Advisory only — the authoritative answer is the `canTrade` flag the
  /// server computes and returns on the depot itself.
  bool get canTrade => this == active;
}
