/// What `POST /api/v1/mobile/depots` records, sent as `depotType`.
///
/// The server also reads `Depot` / `NonDepot`; the app sends the upper-case
/// spelling. Picked by the rep on step 1 of the wizard.
enum MobileDepotKind {
  /// A SAP depot. Needs 1-10 sales areas; may send credit and suppliers.
  depot('DEPOT'),

  /// An outlet that buys through depots. Needs `depots`, 1-20 SAP customer
  /// numbers from the rep's depot list; sales areas, credit and suppliers are
  /// ignored by the server.
  nonDepot('NON_DEPOT');

  const MobileDepotKind(this.apiValue);

  final String apiValue;

  /// The record's `listedAs` / `depotType` in a response: `Draft` and `Depot`
  /// are a depot, `NonDepot` a non-depot. Null when absent or unknown.
  static MobileDepotKind? fromApi(Object? raw) =>
      switch (raw?.toString().toLowerCase().replaceAll(RegExp('[_-]'), '')) {
        'nondepot' => nonDepot,
        'depot' || 'draft' => depot,
        _ => null,
      };
}
