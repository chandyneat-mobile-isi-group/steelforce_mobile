import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_builder_screen.dart';

/// Which account the quotation is priced and promoted against.
///
/// This is a regression test with a specific shape behind it. Several entry
/// points open the builder for a shop the rep has already chosen — the
/// depot card's "create quotation", the checked-in visit flow, the
/// Continue-Working resume — and hold the depot's id without having loaded
/// the whole [Depot]. They passed it as `leadId`, the only slot that
/// existed, so anything reading `depot?.id` saw null and served a rep
/// standing in a known shop as though it were a walk-in: no price on any card
/// and no promotion, with the id sitting in the arguments the whole time.
void main() {
  group('the depot context is found however it was supplied', () {
    test('from a fully loaded depot', () {
      final screen = QuotationBuilderScreen(depot: depotFixture());
      expect(screen.depotContextId, 'cust_1');
    });

    test('from the id alone, which is all several callers have', () {
      const screen = QuotationBuilderScreen(depotId: 'cust_1');
      expect(screen.depotContextId, 'cust_1');
    });

    test('the loaded depot wins when both are given', () {
      // Both are passed on the resume path. They name the same shop; the
      // loaded record is the more authoritative of the two.
      final screen = QuotationBuilderScreen(
        depot: depotFixture(),
        depotId: 'stale_id',
      );
      expect(screen.depotContextId, 'cust_1');
    });
  });

  group('a lead is not a depot', () {
    test('a lead id is never used as the pricing depot', () {
      // A lead is an unregistered shop with no SAP account. Sending its id to
      // `/pricing/depots/{id}` would 404 and render as "depot not
      // found" — an error, where the honest answer is that there is nobody to
      // price for yet.
      const screen = QuotationBuilderScreen(leadId: 'lead_9');
      expect(screen.depotContextId, isNull);
    });

    test('a genuine walk-in has no context at all', () {
      const screen = QuotationBuilderScreen();
      expect(screen.depotContextId, isNull);
    });

    test('a depot opened via the lead slot is still found', () {
      // The exact shape of the bug: `openQuotationForDepot` passes the
      // depot id through `leadId` for the cart, and now through
      // `depotId` as well so pricing sees it.
      const screen = QuotationBuilderScreen(
        depotId: 'cust_1',
        leadId: 'cust_1',
      );
      expect(screen.depotContextId, 'cust_1');
    });
  });
}

/// Keeps the `Depot` construction out of the assertions above.
Depot depotFixture() => Depot(
      id: 'cust_1',
      depotCode: 'C-0001',
      shopName: 'Sok Heng Hardware',
      ownerName: 'Sok',
      phone: '012345678',
      address: 'Street 271',
      province: 'Phnom Penh',
      district: 'Chamkar Mon',
      territory: 'T1',
      latitude: 11.55,
      longitude: 104.92,
      creditLimit: 50000,
      status: DepotStatus.active,
      assignedRepId: 'rep_1',
      assignedRepName: 'Mengchou CHORN',
      updatedAt: DateTime(2026, 1, 1),
    );
