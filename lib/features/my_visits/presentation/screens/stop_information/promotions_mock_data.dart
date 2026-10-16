import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// TODO(release-gate): placeholder promotions for the outlet screen.
///
/// Stands in until the promotions data layer exists — the BRD's `promotion`,
/// `promotion_request` and `promotion_tier` tables (§7) have no Drift schema
/// yet, and building one now would jump ahead of the migration plan
/// (`.claude/CLAUDE.md` §1). Lives in its own file, not inside the widget, so
/// the screen has exactly one line to delete when the repository lands and so
/// this list cannot quietly ship as if it were content.
///
/// Dates are relative to [_today] rather than fixed calendar strings: the old
/// screen hardcoded '31 Aug 2026', which silently became a screen full of
/// expired promotions the day that passed.
final DateTime _today = DateTime.now();

DateTime _inDays(int days) =>
    DateTime(_today.year, _today.month, _today.day + days);

final List<PromoView> mockOutletPromotions = [
  PromoView(
    id: 'P001',
    code: 'ISI-ONINV-5',
    title: 'On-Invoice Discount — Roofing & Wave Tiles',
    summary: 'Instant 5% reduction on all roofing and wave tile orders.',
    kind: PromoKind.onInvoice,
    value: const PromoPercent(5),
    status: PromoStatus.active,
    endsOn: _inDays(4),
    minSpend: '\$2,000',
    category: 'Roofing & Tiles',
  ),
  PromoView(
    id: 'P002',
    code: 'STEEL-BOX-10',
    title: 'Square & Box Pipe Rebate',
    summary: 'Cashback rebate per ton on galvanised square and box pipes.',
    kind: PromoKind.onInvoice,
    value: const PromoAmount('\$10', per: 'Ton'),
    status: PromoStatus.active,
    endsOn: _inDays(21),
    minSpend: '\$5,000',
    category: 'Pipes & Tubing',
  ),
  PromoView(
    id: 'P003',
    code: 'ISI-COD-1',
    title: 'COD / Pickup Discount — All Categories',
    summary: 'Applies when the depot pays on delivery or collects in person.',
    kind: PromoKind.paymentTerm,
    requires: const {PromoRequirement.pickup},
    value: const PromoPercent(1),
    status: PromoStatus.active,
    endsOn: _inDays(48),
    category: 'All Categories',
    depots: 'All Depots',
  ),
  PromoView(
    id: 'P004',
    code: 'CONTRACT-Q3-ISI',
    title: 'Q3 Volume Tier Bonus',
    summary: 'Quarterly incentive for Diamond-tier outlets above 50 tons.',
    kind: PromoKind.volumeTier,
    value: const PromoAmount('\$1,500'),
    status: PromoStatus.active,
    endsOn: _inDays(90),
    minSpend: '\$25,000',
    category: 'All Structural Steel',
  ),
  PromoView(
    id: 'P005',
    code: 'C-PURLIN-SPECIAL',
    title: 'C-Purlin Direct Discount',
    summary: 'Contractor incentive on high-grade C-Purlin and Z-Purlin.',
    kind: PromoKind.onInvoice,
    value: const PromoPercent(3),
    status: PromoStatus.active,
    endsOn: _inDays(30),
    minSpend: '\$1,500',
    category: 'Structural Steel',
  ),
  PromoView(
    id: 'P006',
    code: 'CONTRACT-REBAR-2026',
    title: 'Deformed Bar Annual Agreement',
    summary: 'Agreed contractual rate for high-volume deformed bar purchasing.',
    kind: PromoKind.volumeTier,
    value: const PromoTerms('Special Rate'),
    status: PromoStatus.active,
    endsOn: _inDays(210),
    minSpend: '\$10,000',
    category: 'Rebar & Mesh',
  ),
  // One already finished, so the expired treatment and the sink-to-bottom
  // ordering are visible in the demo rather than only in tests.
  PromoView(
    id: 'P007',
    code: 'ISI-COIL-Q2',
    title: 'Q2 Coil Clearance',
    summary: 'Ran to the end of the second quarter.',
    kind: PromoKind.onInvoice,
    value: const PromoPercent(2.5),
    status: PromoStatus.expired,
    endsOn: _inDays(-12),
    category: 'Coil',
  ),
];
