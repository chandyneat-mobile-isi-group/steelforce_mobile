import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// TODO(release-gate): placeholder promotion groups for the quotation builder.
///
/// Same standing as `my_visits/.../promotions_mock_data.dart`: the BRD's
/// promotion tables (§7) have no Drift schema yet, so there is nothing to read
/// from. Extracted out of the widget it used to be inlined in, both so the
/// section is reviewable as layout and so this data cannot ship unnoticed.
final DateTime _today = DateTime.now();

DateTime _inDays(int days) =>
    DateTime(_today.year, _today.month, _today.day + days);

final List<PromoGroup> mockQuotationPromoGroups = [
  PromoGroup(
    titleKey: 'promotions.group.depot_discount',
    promos: [
      PromoView(
        id: 'Q-DD-1',
        title: 'On-Invoice Discount — Rebar',
        summary: 'Applies to every rebar line on the invoice.',
        kind: PromoKind.onInvoice,
        value: const PromoPercent(2),
        status: PromoStatus.active,
        endsOn: _inDays(26),
        category: 'Rebar',
        depots: 'All Depots',
      ),
      PromoView(
        id: 'Q-DD-2',
        title: 'On-Invoice Discount — Roofing Profile',
        kind: PromoKind.onInvoice,
        value: const PromoPercent(1.5),
        status: PromoStatus.active,
        endsOn: _inDays(26),
        category: 'Roofing Profile',
        depots: 'All Depots',
      ),
      PromoView(
        id: 'Q-DD-3',
        title: 'On-Invoice Discount — PU Eco',
        kind: PromoKind.onInvoice,
        value: const PromoPercent(1.25),
        status: PromoStatus.active,
        endsOn: _inDays(58),
        category: 'PU Eco',
        depots: 'PP, ST Depots',
      ),
      PromoView(
        id: 'Q-DD-4',
        title: 'On-Invoice Discount — ISI 295',
        kind: PromoKind.onInvoice,
        value: const PromoPercent(3),
        status: PromoStatus.active,
        endsOn: _inDays(12),
        category: 'ISI 295',
        depots: 'All Depots',
      ),
    ],
  ),
  PromoGroup(
    titleKey: 'promotions.group.cod_pickup',
    promos: [
      PromoView(
        id: 'Q-CD-1',
        title: 'COD / Pickup Discount — All Categories',
        summary: 'Earned by paying on delivery or collecting from the depot.',
        kind: PromoKind.paymentTerm,
        requires: const {PromoRequirement.pickup},
        value: const PromoPercent(1),
        status: PromoStatus.active,
        endsOn: _inDays(26),
        category: 'All Categories',
        depots: 'All Depots',
      ),
      PromoView(
        id: 'Q-CD-2',
        title: 'COD Discount — Coil',
        kind: PromoKind.paymentTerm,
        requires: const {PromoRequirement.pickup},
        value: const PromoPercent(1.5),
        status: PromoStatus.active,
        endsOn: _inDays(5),
        category: 'Coil',
        depots: 'PP Depot',
      ),
      PromoView(
        id: 'Q-CD-3',
        title: 'Pickup Discount — Profile',
        kind: PromoKind.paymentTerm,
        requires: const {PromoRequirement.pickup},
        value: const PromoPercent(0.75),
        status: PromoStatus.active,
        endsOn: _inDays(40),
        category: 'Profile',
        depots: 'KPS Depot',
      ),
    ],
  ),
  PromoGroup(
    titleKey: 'promotions.group.depot_requests',
    promos: [
      PromoView(
        id: 'Q-RQ-1',
        title: 'Pipe Discount Request',
        summary: 'Waiting on the Regional Sales Manager.',
        kind: PromoKind.depotRequest,
        value: const PromoPercent(1.5),
        status: PromoStatus.pending,
        endsOn: _inDays(26),
        category: 'Pipe',
        depots: 'PP, ST, KPS Depots',
      ),
      PromoView(
        id: 'Q-RQ-2',
        title: 'K Pipe Discount Request',
        kind: PromoKind.depotRequest,
        value: const PromoPercent(1.5),
        status: PromoStatus.approved,
        endsOn: _inDays(26),
        category: 'K Pipe',
        depots: 'PP, ST, KPS Depots',
      ),
      PromoView(
        id: 'Q-RQ-3',
        title: 'Coil Discount Request',
        kind: PromoKind.depotRequest,
        value: const PromoPercent(1),
        status: PromoStatus.approved,
        endsOn: _inDays(26),
        category: 'Coil',
        depots: 'PP, ST, KPS Depots',
      ),
      PromoView(
        id: 'Q-RQ-4',
        title: 'Profile Discount Request',
        kind: PromoKind.depotRequest,
        value: const PromoPercent(2),
        status: PromoStatus.pending,
        endsOn: _inDays(26),
        category: 'Profile',
        depots: 'PP, ST, KPS Depots',
      ),
    ],
  ),
  PromoGroup(
    titleKey: 'promotions.group.free_goods',
    promos: [
      PromoView(
        id: 'Q-FG-1',
        title: 'Camstar Cement Promotion',
        summary: 'Free bags are added to the delivery, not the invoice total.',
        kind: PromoKind.buyXGetY,
        value: const PromoBuyGet(buy: 40, get: 3, unit: 'BAGS'),
        status: PromoStatus.active,
        endsOn: _inDays(26),
        depots: 'All Depots',
      ),
      PromoView(
        id: 'Q-FG-2',
        title: 'Camstar Cement Promotion — Bulk',
        kind: PromoKind.buyXGetY,
        value: const PromoBuyGet(buy: 100, get: 10, unit: 'BAGS'),
        status: PromoStatus.active,
        endsOn: _inDays(26),
        depots: 'All Depots',
      ),
    ],
  ),
];

/// Standard quotation line representation demonstrating how this promotion
/// formats inside an actual commercial quotation with:
/// NO. , Material, Quantity, Discount, Subtotal, Total
class PromoQuotationSampleLine {
  const PromoQuotationSampleLine({
    required this.lineNo,
    required this.materialCode,
    required this.materialName,
    required this.quantity,
    required this.unit,
    required this.unitPriceUsd,
    required this.discountPercent,
    this.bonusNote,
  });

  final int lineNo;
  final String materialCode;
  final String materialName;
  final double quantity;
  final String unit;
  final double unitPriceUsd;
  final double discountPercent;
  final String? bonusNote;

  double get subtotal => quantity * unitPriceUsd;
  double get discountAmount => subtotal * (discountPercent / 100);
  double get total => subtotal - discountAmount;
}

List<PromoQuotationSampleLine> getQuotationSampleLinesForPromo(
    PromoView promo) {
  switch (promo.id) {
    case 'Q-DD-1':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'RB-SD390-D16',
          materialName: 'Deformed Rebar SD390 D16 x 12m',
          quantity: 20,
          unit: 'TON',
          unitPriceUsd: 680.00,
          discountPercent: 2.0,
        ),
      ];
    case 'Q-DD-2':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'RF-PALM-035',
          materialName: 'Palm Profile Roofing Sheet 0.35mm',
          quantity: 120,
          unit: 'PC',
          unitPriceUsd: 14.50,
          discountPercent: 1.5,
        ),
      ];
    case 'Q-DD-3':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'PN-PUECO-040',
          materialName: 'PU Eco Insulated Panel 0.40mm',
          quantity: 40,
          unit: 'PC',
          unitPriceUsd: 28.00,
          discountPercent: 1.25,
        ),
      ];
    case 'Q-DD-4':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'DK-ISI295-075',
          materialName: 'ISI 295 Structural Steel Deck 0.75mm',
          quantity: 80,
          unit: 'PC',
          unitPriceUsd: 22.50,
          discountPercent: 3.0,
        ),
      ];
    case 'Q-CD-1':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'ST-ALL-DEPOT',
          materialName: 'Eligible Depot Pickup Steel Order',
          quantity: 1,
          unit: 'LOT',
          unitPriceUsd: 2500.00,
          discountPercent: 1.0,
        ),
      ];
    case 'Q-CD-2':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'CL-GI-1200',
          materialName: 'GI Steel Coil 1200mm Width',
          quantity: 2,
          unit: 'COIL',
          unitPriceUsd: 1450.00,
          discountPercent: 1.5,
        ),
      ];
    case 'Q-CD-3':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'RF-PRO-040',
          materialName: 'Roofing Profile 0.40mm KPS Depot',
          quantity: 150,
          unit: 'PC',
          unitPriceUsd: 16.00,
          discountPercent: 0.75,
        ),
      ];
    case 'Q-FG-1':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'CM-STAR-40',
          materialName: 'Camstar Portland Cement 50kg',
          quantity: 40,
          unit: 'BAGS',
          unitPriceUsd: 6.50,
          discountPercent: 0.0,
          bonusNote: '+ 3 Bags Free',
        ),
      ];
    case 'Q-FG-2':
      return const [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: 'CM-STAR-100',
          materialName: 'Camstar Portland Cement Bulk 50kg',
          quantity: 100,
          unit: 'BAGS',
          unitPriceUsd: 6.20,
          discountPercent: 0.0,
          bonusNote: '+ 10 Bags Free',
        ),
      ];
    default:
      final rate = switch (promo.value) {
        PromoPercent p => p.percent,
        _ => 1.5,
      };
      return [
        PromoQuotationSampleLine(
          lineNo: 1,
          materialCode: (promo.category != null && promo.category!.isNotEmpty)
              ? '${promo.category!.toUpperCase().replaceAll(' ', '-')}-01'
              : 'MAT-${promo.id}',
          materialName: promo.title,
          quantity: 50,
          unit: 'PC',
          unitPriceUsd: 20.00,
          discountPercent: rate,
        ),
      ];
  }
}
