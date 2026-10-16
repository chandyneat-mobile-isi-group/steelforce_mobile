import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/models/material_api_mapper.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';

/// The exact `data` block the staging server returns for
/// `GET /api/v1/materials/1100000005/availability` with no sales-area
/// parameters. Pinned verbatim rather than hand-written, because every
/// assertion below is about a shape we do not control.
const DataMap _inputIncomplete = {
  'material': '1100000005',
  'isSellable': false,
  'summary':
      'Validation not performed. Mandatory input parameters are missing.',
  'checks': [
    {
      'sequence': '001',
      'checkId': 'INPUT_VKORG',
      'status': 'E',
      'message': 'Sales Organization is required.',
      'isVerdict': false,
    },
    {
      'sequence': '002',
      'checkId': 'INPUT_VTWEG',
      'status': 'E',
      'message': 'Distribution Channel is required.',
      'isVerdict': false,
    },
    {
      'sequence': '003',
      'checkId': 'RESULT',
      'status': 'E',
      'message':
          'Validation not performed. Mandatory input parameters are missing.',
      'isVerdict': true,
    },
  ],
};

/// A genuine business refusal, for contrast: the material exists but is not
/// extended to the sales area.
const DataMap _notExtended = {
  'material': '2400001439',
  'isSellable': false,
  'summary': 'Material is not available for sale in 1000/10.',
  'checks': [
    {
      'sequence': '001',
      'checkId': 'MATERIAL',
      'status': 'S',
      'message': 'Material 2400001439 exists.',
      'isVerdict': false,
    },
    {
      'sequence': '002',
      'checkId': 'SALES_VIEW',
      'status': 'E',
      'message': 'Material is not extended to sales area 1000/10.',
      'isVerdict': false,
    },
    {
      'sequence': '003',
      'checkId': 'RESULT',
      'status': 'E',
      'message': 'Material is not available for sale in 1000/10.',
      'isVerdict': true,
    },
  ],
};

const DataMap _sellable = {
  'material': '2400000730',
  'isSellable': true,
  'summary': 'Material is available for sale in 1000/10.',
  'checks': [
    {
      'sequence': '001',
      'checkId': 'RESULT',
      'status': 'S',
      'message': 'Material is available for sale in 1000/10.',
      'isVerdict': true,
    },
  ],
};

/// The live `GET /mobile/materials/1100000042/stock` payload.
const DataMap _stockHigh = {
  'material': '1100000042',
  'band': 'High',
  'isSellable': true,
  'baseUnit': 'KG',
  'plants': [
    {'plant': 'KMH2', 'band': 'High', 'isSellable': true},
  ],
  'checkedAt': '2026-08-27T07:51:39.9213697+00:00',
};

const DataMap _stockNone = {
  'material': '1100000099',
  'band': 'None',
  'isSellable': false,
  'baseUnit': 'M',
  'plants': <DataMap>[],
  'checkedAt': '2026-08-27T07:51:39.9213697+00:00',
};

const DataMap _stockLow = {
  'material': '1100000077',
  'band': 'Low',
  'isSellable': true,
  'baseUnit': 'M',
  'plants': [
    {'plant': 'KMH2', 'band': 'Low', 'isSellable': true},
    {'plant': 'KMH9', 'band': 'None', 'isSellable': false},
  ],
  'checkedAt': '2026-08-27T07:51:39.9213697+00:00',
};

void main() {
  group('banded stock', () {
    test('a High band is sellable and orderable', () {
      final stock =
          MaterialApiMapper.stockFrom(_stockHigh, requested: '1100000042');

      expect(stock.isSellable, isTrue);
      expect(stock.status, MaterialStockStatus.available);
      expect(stock.band, StockBand.high);
      expect(stock.baseUnit, 'KG');
      expect(stock.canOrder, isTrue);
    });

    test('a Low band still lets the rep order', () {
      // The distinction the quantity stepper hangs on: "Low" warns about how
      // much, it does not refuse. Gating `+` on the band would block orders
      // SAP would accept.
      final stock =
          MaterialApiMapper.stockFrom(_stockLow, requested: '1100000077');

      expect(stock.band, StockBand.low);
      expect(stock.canOrder, isTrue);
    });

    test('a None band with isSellable false cannot be ordered', () {
      final stock =
          MaterialApiMapper.stockFrom(_stockNone, requested: '1100000099');

      expect(stock.status, MaterialStockStatus.unavailable);
      expect(stock.canOrder, isFalse);
    });

    test('an unchecked material is orderable, not blocked', () {
      // Never asked is not a refusal. A rep must not be stopped by a question
      // the handset has not got round to putting.
      const unchecked = MaterialAvailability(
        material: '1100000042',
        isSellable: false,
        summary: '',
      );

      expect(unchecked.status, MaterialStockStatus.unknown);
      expect(unchecked.canOrder, isTrue);
    });

    test('only sellable plants are offered as sources', () {
      final stock =
          MaterialApiMapper.stockFrom(_stockLow, requested: '1100000077');

      expect(stock.plants, hasLength(2));
      expect(stock.sellablePlants.map((p) => p.plant), ['KMH2']);
    });

    test('an unrecognised band degrades to unknown, never to none', () {
      // Inventing "there is no stock" out of a string this build has not seen
      // would stop a sale that should have gone ahead.
      final stock = MaterialApiMapper.stockFrom(
        {..._stockHigh, 'band': 'Plentiful'},
        requested: '1100000042',
      );

      expect(stock.band, StockBand.unknown);
      expect(stock.canOrder, isTrue);
    });
  });

  group('availability verdicts', () {
    test('a sellable material reads as available', () {
      final verdict = MaterialApiMapper.availabilityFrom(
        _sellable,
        requested: '2400000730',
      );

      expect(verdict.isSellable, isTrue);
      expect(verdict.status, MaterialStockStatus.available);
      expect(verdict.isInputIncomplete, isFalse);
    });

    test('a refused material reads as unavailable — the "No stock" badge', () {
      final verdict = MaterialApiMapper.availabilityFrom(
        _notExtended,
        requested: '2400001439',
      );

      expect(verdict.status, MaterialStockStatus.unavailable);
      expect(verdict.isInputIncomplete, isFalse);
    });

    test('the reason names the cause, not the conclusion', () {
      // The verdict check only restates the summary. What a rep can act on is
      // the failing check underneath it — "not extended to sales area 1000/10"
      // is a phone call they can make; "not available for sale" is not.
      final verdict = MaterialApiMapper.availabilityFrom(
        _notExtended,
        requested: '2400001439',
      );

      expect(verdict.reason, 'Material is not extended to sales area 1000/10.');
      expect(verdict.blockingChecks.map((c) => c.checkId), ['SALES_VIEW']);
    });
  });

  group('missing sales-area parameters', () {
    test('renders as unavailable', () {
      // The product decision on record: until the rep's sales area is resolved
      // and sent, an unanswerable check shows as "No stock" rather than as a
      // silent pass. It never invents a yes.
      final verdict = MaterialApiMapper.availabilityFrom(
        _inputIncomplete,
        requested: '1100000005',
      );

      expect(verdict.isSellable, isFalse);
      expect(verdict.status, MaterialStockStatus.unavailable);
    });

    test('is still distinguishable from a business refusal', () {
      // The distinction has to survive into the entity even though the badge
      // currently collapses both to "No stock". SAP answered 200 here: the
      // validation never ran, which is a client-side gap someone has to close,
      // and it must not disappear into the same bucket as a real verdict.
      final unanswerable = MaterialApiMapper.availabilityFrom(
        _inputIncomplete,
        requested: '1100000005',
      );
      final refused = MaterialApiMapper.availabilityFrom(
        _notExtended,
        requested: '2400001439',
      );

      expect(unanswerable.isInputIncomplete, isTrue);
      expect(refused.isInputIncomplete, isFalse);
    });

    test('surfaces which parameters SAP wanted', () {
      final verdict = MaterialApiMapper.availabilityFrom(
        _inputIncomplete,
        requested: '1100000005',
      );

      expect(
        verdict.blockingChecks.map((c) => c.checkId),
        ['INPUT_VKORG', 'INPUT_VTWEG'],
      );
      expect(verdict.reason, 'Sales Organization is required.');
    });
  });

  test('the requested number keys the result, not the echoed one', () {
    // The verdict is looked up by what was asked for. A server that trimmed or
    // re-formatted the number would otherwise leave the result orphaned
    // against every card on screen.
    final verdict = MaterialApiMapper.availabilityFrom(
      {..._sellable, 'material': ' 2400000730 '},
      requested: '2400000730',
    );

    expect(verdict.material, '2400000730');
  });

  test('a check in flight is neither a yes nor a no', () {
    const pending = MaterialAvailability.checking('2400000730');

    expect(pending.status, MaterialStockStatus.checking);
    expect(pending.checks, isEmpty);
    expect(pending.isInputIncomplete, isFalse);
  });
}
