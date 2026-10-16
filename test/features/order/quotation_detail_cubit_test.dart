import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetQuotationDetail extends Mock implements GetQuotationDetail {}

class _MockSubmitQuotation extends Mock implements SubmitQuotation {}

class _MockRepriceQuotation extends Mock implements RepriceQuotation {}

class _MockCancelQuotation extends Mock implements CancelQuotation {}

class _MockGetQuotationHistory extends Mock implements GetQuotationHistory {}

QuotationDetail _detail(String id,
    {String status = 'Draft', double net = 300.0}) {
  return QuotationDetail(
    id: id,
    number: 'QT-$id',
    depotId: 'cust-1',
    depotName: 'Depot One',
    status: status,
    statusGroup: status == 'Draft'
        ? QuotationStatusGroup.drafts
        : QuotationStatusGroup.waiting,
    shipmentType: 'Pickup',
    currency: 'US3',
    revision: 1,
    requiredApprovalLevel: 1,
    lines: const [],
    totals: QuotationTotals(
      currency: 'US3',
      gross: net,
      discountTotal: 0.0,
      net: net,
      isEstimate: false,
    ),
    createdAt: DateTime(2026, 9, 12),
  );
}

void main() {
  late _MockGetQuotationDetail mockGetDetail;
  late _MockSubmitQuotation mockSubmit;
  late _MockRepriceQuotation mockReprice;
  late _MockCancelQuotation mockCancel;
  late _MockGetQuotationHistory mockGetHistory;

  setUpAll(() {
    registerFallbackValue(const QuotationIdParams('qt-fallback'));
  });

  setUp(() {
    mockGetDetail = _MockGetQuotationDetail();
    mockSubmit = _MockSubmitQuotation();
    mockReprice = _MockRepriceQuotation();
    mockCancel = _MockCancelQuotation();
    mockGetHistory = _MockGetQuotationHistory();
  });

  QuotationDetailCubit build() => QuotationDetailCubit(
        getQuotationDetail: mockGetDetail,
        submitQuotation: mockSubmit,
        repriceQuotation: mockReprice,
        cancelQuotation: mockCancel,
        getQuotationHistory: mockGetHistory,
      );

  group('QuotationDetailCubit', () {
    blocTest<QuotationDetailCubit, QuotationDetailState>(
      'loads quotation detail and history successfully',
      build: () {
        when(() => mockGetDetail(any())).thenAnswer(
          (_) async => Success(_detail('100')),
        );
        when(() => mockGetHistory(any())).thenAnswer(
          (_) async => const Success(<QuotationApprovalHistory>[]),
        );
        return build();
      },
      act: (cubit) => cubit.load('100'),
      expect: () => [
        const QuotationDetailLoading(),
        isA<QuotationDetailLoaded>()
            .having((s) => s.quotation.id, 'id', '100')
            .having((s) => s.quotation.totals.currency, 'currency', 'US3'),
      ],
    );

    blocTest<QuotationDetailCubit, QuotationDetailState>(
      'handles 409 Quotation.PriceChanged gracefully and emits QuotationDetailPriceChanged',
      build: () {
        when(() => mockSubmit(any())).thenAnswer(
          (_) async => const Failed(
            ServerFailure(
              message: 'Prices have changed in SAP since draft was created.',
              code: 'Quotation.PriceChanged',
            ),
          ),
        );
        return build();
      },
      seed: () => QuotationDetailLoaded(
        quotation: _detail('100'),
        history: const [],
      ),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<QuotationDetailLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<QuotationDetailPriceChanged>()
            .having((s) => s.quotation.id, 'id', '100')
            .having((s) => s.message, 'message',
                contains('Prices have changed in SAP')),
      ],
    );

    blocTest<QuotationDetailCubit, QuotationDetailState>(
      'repricing updates quotation with fresh server prices',
      build: () {
        when(() => mockReprice(any())).thenAnswer(
          (_) async => Success(_detail('100', net: 350.0)),
        );
        return build();
      },
      seed: () => QuotationDetailPriceChanged(
        quotation: _detail('100', net: 300.0),
        message: 'Prices have changed.',
      ),
      act: (cubit) => cubit.reprice(),
      expect: () => [
        isA<QuotationDetailLoaded>()
            .having((s) => s.isRepricing, 'isRepricing', true),
        isA<QuotationDetailLoaded>()
            .having((s) => s.isRepricing, 'isRepricing', false)
            .having((s) => s.quotation.totals.net, 'net', 350.0),
      ],
    );
  });
}
