/// Which list a depot row belongs to on the Depots screen.
///
/// `GET /mobile/depots` answers in three groups — `depots`, `nonDepots` and
/// `draft` (itself `depots` + `nonDepots`, not yet approved) — and each row is
/// stored with its group in `depot_type` ([DepotTypes]).
enum DepotListKind {
  /// SAP depots — the trading list.
  depot,

  /// Approved Non-BP depots.
  nonBp,

  /// Recorded by the rep and not yet approved: new depots and new Non-BP
  /// depots alike.
  awaitingApproval;

  /// The kind of a stored `depot_type`. Null — a row synced before the type
  /// was sent — is a depot, which is all the list ever held then.
  static DepotListKind of(String? depotType) => switch (depotType) {
        DepotTypes.nonDepot => nonBp,
        DepotTypes.draft || DepotTypes.nonDepotDraft => awaitingApproval,
        _ => depot,
      };

  /// The stored `depot_type` values of this kind. A depot also matches a
  /// row with no type ([includesUntyped]).
  List<String> get storedTypes => switch (this) {
        depot => const [DepotTypes.depot],
        nonBp => const [DepotTypes.nonDepot],
        awaitingApproval => const [
            DepotTypes.draft,
            DepotTypes.nonDepotDraft,
          ],
      };

  bool get includesUntyped => this == depot;
}

/// The values the local `depot_type` column holds.
///
/// The first three are the server's own `depotType`. [nonDepotDraft] is the
/// app's: a Non-BP depot awaiting approval arrives as `NonDepot` under
/// `draft.nonDepots`, and is stored apart so it lists with the drafts.
abstract final class DepotTypes {
  static const depot = 'Depot';
  static const nonDepot = 'NonDepot';
  static const draft = 'Draft';
  static const nonDepotDraft = 'NonDepotDraft';
}
