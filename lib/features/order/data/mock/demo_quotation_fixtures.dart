import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_document.dart';

/// One seeded quotation, as intent: who, what, and how far it has travelled.
typedef _Seed = ({
  int depot,
  String status,
  int ageDays,
  String shipment,
  List<(String, double, double)> lines,
  String? reason,
});

/// The demo rep's existing quotation book.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Sixteen documents across the shared [DemoSeed] depots, one or more in every
/// tab group, dated relative to today so "2 days ago" stays true on any demo
/// day. Lines name ISI demo-catalog materials at their catalog price, and
/// totals are derived by [DemoQuotationDoc] — never typed in — so they always
/// add up. Ids are stable (`dq-seed-NN`) so a notification can deep-link to
/// one and so they survive an app restart.
abstract final class DemoQuotationFixtures {
  /// First number handed to a quotation the rep opens during the demo.
  static const int firstNewSequence = 420;

  static String number(DateTime now, int sequence) =>
      'Q-${now.year}-${sequence.toString().padLeft(4, '0')}';

  static String seedId(int index) =>
      'dq-seed-${index.toString().padLeft(2, '0')}';

  static final List<_Seed> _seeds = [
    (
      depot: 0,
      status: 'Draft',
      ageDays: 0,
      shipment: 'Pickup',
      reason: null,
      lines: [('2400001018', 420, 0), ('2400000851', 60, 0)]
    ),
    (
      depot: 2,
      status: 'Draft',
      ageDays: 1,
      shipment: 'Delivery',
      reason: null,
      lines: [('1400000891', 40, 1.5), ('2400000568', 300, 0)]
    ),
    (
      depot: 4,
      status: 'Returned',
      ageDays: 6,
      shipment: 'Pickup',
      reason:
          'Manual discount on TILE 1000 is above 3%. Reduce to 2% and resubmit.',
      lines: [('2400001070', 800, 4.0), ('1400000730', 24, 0)]
    ),
    (
      depot: 1,
      status: 'PendingApproval',
      ageDays: 1,
      shipment: 'Pickup',
      reason: null,
      lines: [('2400001024', 650, 1.0), ('2400002043', 120, 0)]
    ),
    (
      depot: 3,
      status: 'PendingApproval',
      ageDays: 2,
      shipment: 'Delivery',
      reason: null,
      lines: [('2400002686', 180, 0), ('2400002704', 240, 0.5)]
    ),
    (
      depot: 5,
      status: 'PendingApproval',
      ageDays: 3,
      shipment: 'Pickup',
      reason: null,
      lines: [('1400001078', 30, 2.0)]
    ),
    (
      depot: 6,
      status: 'Approved',
      ageDays: 5,
      shipment: 'Delivery',
      reason: null,
      lines: [('1500000327', 400, 0), ('1500000868', 150, 0)]
    ),
    (
      depot: 0,
      status: 'Approved',
      ageDays: 8,
      shipment: 'Pickup',
      reason: null,
      lines: [('1400000732', 60, 1.0), ('1400000720', 12, 0)]
    ),
    (
      depot: 7,
      status: 'Quoted',
      ageDays: 10,
      shipment: 'Delivery',
      reason: null,
      lines: [('1500000071', 6, 0), ('1500000075', 10, 0)]
    ),
    (
      depot: 8,
      status: 'Accepted',
      ageDays: 14,
      shipment: 'Pickup',
      reason: null,
      lines: [('2400004576', 500, 1.0), ('1400001139', 200, 0)]
    ),
    (
      depot: 9,
      status: 'Ordered',
      ageDays: 18,
      shipment: 'Delivery',
      reason: null,
      lines: [('2400000696', 350, 0), ('2400000660', 200, 0)]
    ),
    (
      depot: 1,
      status: 'Ordered',
      ageDays: 21,
      shipment: 'Pickup',
      reason: null,
      lines: [('2400001072', 900, 1.5), ('2400000854', 90, 0)]
    ),
    (
      depot: 10,
      status: 'Rejected',
      ageDays: 9,
      shipment: 'Pickup',
      reason:
          'Depot is over its credit limit. Collect the overdue balance first.',
      lines: [('1400000858', 80, 2.5)]
    ),
    (
      depot: 2,
      status: 'Rejected',
      ageDays: 16,
      shipment: 'Delivery',
      reason: 'Price requested is below the project floor for decking.',
      lines: [('2400000544', 400, 3.0)]
    ),
    (
      depot: 11,
      status: 'Cancelled',
      ageDays: 12,
      shipment: 'Pickup',
      reason: null,
      lines: [('2400000811', 140, 0)]
    ),
    (
      depot: 3,
      status: 'Expired',
      ageDays: 30,
      shipment: 'Delivery',
      reason: null,
      lines: [('1400001137', 300, 0), ('1400001050', 150, 0)]
    ),
  ];

  /// The status trail each seeded status has been through after `Created`.
  static const Map<String, List<String>> _trail = {
    'Draft': [],
    'Returned': ['Submitted', 'Returned'],
    'PendingApproval': ['Submitted'],
    'Approved': ['Submitted', 'Approved'],
    'Quoted': ['Submitted', 'Approved', 'SubmittedToSap', 'Quoted'],
    'Accepted': [
      'Submitted',
      'Approved',
      'SubmittedToSap',
      'Quoted',
      'Accepted'
    ],
    'Ordered': [
      'Submitted',
      'Approved',
      'SubmittedToSap',
      'Quoted',
      'Accepted',
      'Ordered',
    ],
    'Rejected': ['Submitted', 'Rejected'],
    'Cancelled': ['Cancelled'],
    'Expired': ['Submitted', 'Approved', 'SubmittedToSap', 'Quoted', 'Expired'],
  };

  static const _decisions = {'Approved', 'Returned', 'Rejected'};

  static List<DemoQuotationDoc> build(DateTime now) => [
        for (var i = 0; i < _seeds.length; i++) _build(i + 1, _seeds[i], now),
      ];

  static DemoQuotationDoc _build(int index, _Seed seed, DateTime now) {
    final created = DateTime(now.year, now.month, now.day - seed.ageDays, 9)
        .add(Duration(minutes: index * 17));
    final depot = DemoSeed.depots[seed.depot];
    final doc = DemoQuotationDoc(
      id: seedId(index),
      number: number(now, 400 + index),
      depotId: depot.id,
      status: seed.status,
      createdAt: created,
      shipmentType: seed.shipment,
      shipTo: seed.shipment == 'Delivery'
          ? '${depot.name}, ${depot.district}, ${depot.province}'
          : null,
      paymentTerm: index.isEven ? 'NT30' : 'COD',
      depotReference: 'PO-${(4400 + index * 7)}',
    );
    for (var l = 0; l < seed.lines.length; l++) {
      final (number, quantity, manual) = seed.lines[l];
      final material = DemoMaterialBook.isi(number);
      doc.lines.add(DemoQuotationLine(
        id: '${doc.id}-l${l + 1}',
        material: material,
        quantity: quantity,
        priceAmount: material.price,
        pricedAt: created,
        manualPercent: manual,
      ));
    }
    _applyTrail(doc, seed, created);
    return doc;
  }

  static void _applyTrail(DemoQuotationDoc doc, _Seed seed, DateTime created) {
    doc.history.add(DemoHistoryEntry('${doc.id}-h0', 'Created', created,
        actorName: DemoSeed.repName));
    var at = created;
    final steps = _trail[seed.status] ?? const <String>[];
    for (var s = 0; s < steps.length; s++) {
      final action = steps[s];
      at = at.add(Duration(hours: s == 0 ? 2 : 20));
      final byRep = action == 'Submitted' || action == 'Cancelled';
      final isDecision = _decisions.contains(action);
      doc.history.add(DemoHistoryEntry('${doc.id}-h${s + 1}', action, at,
          actorName: byRep ? DemoSeed.repName : DemoSeed.managerName,
          comment: isDecision && action != 'Approved' ? seed.reason : null));
      if (action == 'Submitted') doc.submittedAt = at;
      if (isDecision) {
        doc.decidedAt = at;
        doc.decidedBy = DemoSeed.managerName;
        doc.decisionReason = action == 'Approved' ? null : seed.reason;
      }
    }
    if (seed.status == 'Returned') doc.revision = 2;
    doc.updatedAt = at;
    if (seed.status == 'Expired') {
      doc.validTo = created.add(const Duration(days: 15));
    }
  }
}
