/// The demo backend's depot table, held in memory for the app session.
///
/// Shared by every demo depot source so a write through one is visible to the
/// others: a shop registered through the business-partner endpoint appears in
/// the next delta sync, opens on the detail screen and has stop information —
/// as it would against the real server.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_fixtures.dart';

class DemoDepotDirectory {
  DemoDepotDirectory({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _rows.addAll(DemoDepotFixtures.seedRows(_clock()));
  }

  final DateTime Function() _clock;
  final List<DataMap> _rows = [];
  int _created = 0;

  /// The server clock. Watermarks come from here, never the caller.
  DateTime now() => _clock().toUtc();

  /// Rows in the order the list endpoint sorts by: `updatedAt`, then id, so
  /// paging is stable between requests.
  List<DataMap> get sorted => [..._rows]..sort((a, b) {
      final byTime =
          (a['updatedAt'] as String).compareTo(b['updatedAt'] as String);
      return byTime != 0
          ? byTime
          : (a['id'] as String).compareTo(b['id'] as String);
    });

  /// Rows changed at or after [since], tombstones included.
  List<DataMap> changedSince(DateTime since) => sorted
      .where((row) =>
          !DateTime.parse(row['updatedAt'] as String).isBefore(since.toUtc()))
      .toList();

  /// Matches the platform id **or** the depot code, as the real routes do.
  DataMap? find(String idOrCode) {
    for (final row in _rows) {
      if (row['id'] == idOrCode || row['customerCode'] == idOrCode) {
        return row;
      }
    }
    return null;
  }

  bool hasCode(String code) =>
      code.isNotEmpty && _rows.any((row) => row['customerCode'] == code);

  /// A fresh platform id, unique for the session.
  String nextId() =>
      'demo-depot-new-${(++_created).toString().padLeft(3, '0')}';

  /// The next free SAP business-partner number after the seeded range.
  String nextPartnerNumber() {
    var highest = 0;
    for (final row in _rows) {
      final code = int.tryParse(row['customerCode'] as String? ?? '') ?? 0;
      if (code > highest) highest = code;
    }
    return (highest + 1).toString().padLeft(10, '0');
  }

  /// Inserts [row], stamping `createdAt` and `updatedAt` with the server clock
  /// so the next delta picks it up.
  DataMap insert(DataMap row) {
    final stamp = DemoDepotFixtures.iso(now());
    final stored = {...row, 'createdAt': stamp, 'updatedAt': stamp};
    _rows.add(stored);
    return stored;
  }
}
