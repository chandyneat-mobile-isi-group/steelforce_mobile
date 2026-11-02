/// Identifiers shared by every feature's practice data, so the demo depot a
/// rep creates a quotation for is the same one their demo visit stops at.
///
/// All carry a `practice-` prefix: should one ever be seen outside a practice
/// session, it is recognisable at a glance as demo data and not a real record.
abstract final class PracticeIds {
  /// The ready-made demo depot every lesson can use.
  static const depotId = 'practice-depot-001';
  static const depotCode = 'PRACTICE-001';
  static const depotNameEn = 'Sokha Hardware (Practice)';
  static const depotNameKh = 'ហាងលក់គ្រឿងដែក សុខា (ហ្វឹកហាត់)';

  /// Prefix for depots registered during a practice run.
  static const createdDepotPrefix = 'practice-depot-new-';

  /// Today's demo route and its one stop.
  static const routeId = 'practice-route-001';
  static const stopId = 'practice-stop-001';

  /// The approved demo quotation the order lesson converts.
  static const approvedQuotationId = 'practice-quotation-approved';

  /// Prefix for quotations and orders made during a practice run.
  static const quotationPrefix = 'practice-qt-';
  static const salesOrderPrefix = 'practice-so-';

  /// True for any id minted by practice data.
  static bool isPractice(String? id) =>
      id != null && id.startsWith('practice-');
}
