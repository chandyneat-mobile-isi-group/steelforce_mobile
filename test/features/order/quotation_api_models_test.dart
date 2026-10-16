import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/models/quotation_api_models.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

void main() {
  group('QuotationApiModels JSON serialization', () {
    test('QuotationSummaryModel parses from JSON correctly', () {
      final json = {
        'id': 'qt-100',
        'number': 'QT-2026-001',
        'depotId': 'cust-1',
        'depotName': 'Chandy Steel Depot',
        'status': 'Draft',
        'statusGroup': 'Drafts',
        'currency': 'US3',
        'net': 1500.50,
        'lineCount': 3,
        'validTo': '2026-10-01T00:00:00.000Z',
        'createdAt': '2026-09-12T08:00:00.000Z',
        'updatedAt': '2026-09-12T08:30:00.000Z',
      };

      final model = QuotationSummaryModel.fromJson(json);
      expect(model.id, 'qt-100');
      expect(model.number, 'QT-2026-001');
      expect(model.depotId, 'cust-1');
      expect(model.depotName, 'Chandy Steel Depot');
      expect(model.status, 'Draft');
      expect(model.statusGroup, QuotationStatusGroup.drafts);
      expect(model.currency, 'US3');
      expect(model.net, 1500.50);
      expect(model.lineCount, 3);
      expect(model.validTo, DateTime.parse('2026-10-01T00:00:00.000Z'));
    });

    test(
        'QuotationDetailModel with lines, discounts, and totals parses correctly',
        () {
      final json = {
        'id': 'qt-200',
        'number': 'QT-2026-002',
        'depotId': 'cust-2',
        'depotName': 'Phnom Penh Builders',
        'status': 'PendingApproval',
        'statusGroup': 'Waiting',
        'shipmentType': 'Pickup',
        'currency': 'US3',
        'revision': 1,
        'requiredApprovalLevel': 2,
        'lines': [
          {
            'id': 'line-1',
            'lineNumber': 10,
            'materialNumber': 'MAT-100',
            'materialDescription': 'Galvanized C-Purlin 100x50',
            'quantity': 50.0,
            'unit': 'PC',
            'price': {
              'amount': 47.50,
              'currency': 'US3',
              'pricingUnit': 100.0,
              'conditionUnit': 'KG',
            },
            'discounts': [
              {
                'id': 'disc-1',
                'kind': 'Manual',
                'percent': 3.5,
                'editable': true,
              },
              {
                'id': 'disc-2',
                'kind': 'Agreement',
                'percent': 2.0,
                'editable': false,
                'sourceReference': 'AGR-2026-01',
              }
            ],
            'gross': 237.50,
            'discountTotal': 13.06,
            'net': 224.44,
          }
        ],
        'totals': {
          'currency': 'US3',
          'gross': 237.50,
          'discountTotal': 13.06,
          'net': 224.44,
          'isEstimate': false,
          'tax': 22.44,
        },
        'createdAt': '2026-09-12T09:00:00.000Z',
      };

      final model = QuotationDetailModel.fromJson(json);
      expect(model.id, 'qt-200');
      expect(model.statusGroup, QuotationStatusGroup.waiting);
      expect(model.requiredApprovalLevel, 2);
      expect(model.lines.length, 1);

      final line = model.lines.first;
      expect(line.materialNumber, 'MAT-100');
      expect(line.pricePricingUnit, 100.0);
      expect(line.priceConditionUnit, 'KG');
      expect(line.formattedPrice, '47.500 US3 / 100 KG');
      expect(line.discounts.length, 2);
      expect(line.manualDiscount?.percent, 3.5);
      expect(line.agreementDiscounts.length, 1);
      expect(line.agreementDiscounts.first.sourceReference, 'AGR-2026-01');

      expect(model.totals.currency, 'US3');
      expect(model.totals.gross, 237.50);
      expect(model.totals.discountTotal, 13.06);
      expect(model.totals.net, 224.44);
      expect(model.totals.isEstimate, false);
      expect(model.totals.tax, 22.44);
    });

    test('QuotationPreviewModel parses warnings and limits', () {
      final json = {
        'quotationId': 'qt-300',
        'lines': [],
        'totals': {
          'currency': 'US3',
          'gross': 0.0,
          'discountTotal': 0.0,
          'net': 0.0,
          'isEstimate': true,
        },
        'warnings': [
          {
            'code': 'MOQ_NOT_MET',
            'lineId': 'line-1',
            'message': 'Minimum order quantity for purlins is 500 KG',
          }
        ],
        'manualDiscountLimitPercent': 10.0,
        'lineDiscountCapPercent': 15.0,
        'requiredApprovalLevel': 1,
      };

      final model = QuotationPreviewModel.fromJson(json);
      expect(model.quotationId, 'qt-300');
      expect(model.manualDiscountLimitPercent, 10.0);
      expect(model.lineDiscountCapPercent, 15.0);
      expect(model.requiredApprovalLevel, 1);
      expect(model.warnings.length, 1);
      expect(model.warnings.first.code, 'MOQ_NOT_MET');
      expect(model.warnings.first.message,
          'Minimum order quantity for purlins is 500 KG');
    });

    test('DepotAgreementModel parses correctly', () {
      final json = {
        'id': 'agr-50',
        'category': 'Roofing',
        'percent': 2.5,
        'kind': 'StandingDiscount',
        'status': 'Active',
        'effectiveFrom': '2026-01-01T00:00:00.000Z',
        'endsOn': '2026-12-31T23:59:59.000Z',
      };

      final model = DepotAgreementModel.fromJson(json);
      expect(model.id, 'agr-50');
      expect(model.category, 'Roofing');
      expect(model.percent, 2.5);
      expect(model.kind, 'StandingDiscount');
      expect(model.status, 'Active');
    });
  });
}
