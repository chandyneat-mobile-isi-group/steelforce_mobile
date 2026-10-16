/// TODO(release-gate): placeholder order history for the outlet screen.
///
/// Every depot is shown these same five orders. Stands in until the screen
/// reads the depot's real sales orders (`features/order`'s `SalesOrder`
/// entity and repository). Lives in its own file, not inside the screen, so
/// the placeholder is visible as one and cannot quietly ship as content.
/// The types are named `OrderHistory*` so they do not shadow the domain
/// `SalesOrder`.
enum OrderHistoryStatus { completed, inDelivery, pending, cancelled }

class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.orderId,
    required this.sapDocNum,
    required this.orderDate,
    required this.totalAmount,
    required this.itemCount,
    required this.status,
    required this.paymentTerm,
    required this.itemsSummary,
  });

  final String orderId;
  final String sapDocNum;
  final String orderDate;
  final double totalAmount;
  final int itemCount;
  final OrderHistoryStatus status;
  final String paymentTerm;
  final String itemsSummary;

  /// Order ID and items match case-insensitively; the SAP doc number exactly.
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    return orderId.toLowerCase().contains(lower) ||
        sapDocNum.contains(query) ||
        itemsSummary.toLowerCase().contains(lower);
  }
}

const List<OrderHistoryEntry> mockOrderHistory = [
  OrderHistoryEntry(
    orderId: 'ORD-2026-8891',
    sapDocNum: '30018923',
    orderDate: '12 Aug 2026',
    totalAmount: 14250.00,
    itemCount: 4,
    status: OrderHistoryStatus.completed,
    paymentTerm: '30 Days Net',
    itemsSummary:
        'ISI Wave Tile (Red) x 1,200 Sheets, Square Box Pipe x 3 Tons',
  ),
  OrderHistoryEntry(
    orderId: 'ORD-2026-8710',
    sapDocNum: '30018804',
    orderDate: '28 Jul 2026',
    totalAmount: 9800.50,
    itemCount: 2,
    status: OrderHistoryStatus.inDelivery,
    paymentTerm: 'Cash on Delivery',
    itemsSummary: 'Galvanized C-Purlin 100x50 x 500 Pcs',
  ),
  OrderHistoryEntry(
    orderId: 'ORD-2026-8540',
    sapDocNum: '30018610',
    orderDate: '15 Jul 2026',
    totalAmount: 22100.00,
    itemCount: 6,
    status: OrderHistoryStatus.completed,
    paymentTerm: '30 Days Net',
    itemsSummary: 'Deformed Bar DB12 x 15 Tons, Wire Mesh 6mm x 20 Rolls',
  ),
  OrderHistoryEntry(
    orderId: 'ORD-2026-8230',
    sapDocNum: '30018300',
    orderDate: '02 Jul 2026',
    totalAmount: 5400.00,
    itemCount: 1,
    status: OrderHistoryStatus.pending,
    paymentTerm: 'Prepayment',
    itemsSummary: 'ISI Roofing Panel Blue x 450 Sheets',
  ),
  OrderHistoryEntry(
    orderId: 'ORD-2026-7990',
    sapDocNum: '30017992',
    orderDate: '18 Jun 2026',
    totalAmount: 11000.00,
    itemCount: 3,
    status: OrderHistoryStatus.completed,
    paymentTerm: '30 Days Net',
    itemsSummary: 'H-Beam 150x150 x 10 Tons',
  ),
];
