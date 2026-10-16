import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_builder_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpenQuotation extends Mock implements OpenQuotation {}

class _MockGetQuotationDetail extends Mock implements GetQuotationDetail {}

class _MockUpdateQuotationHeader extends Mock
    implements UpdateQuotationHeader {}

class _MockAddQuotationLine extends Mock implements AddQuotationLine {}

class _MockUpdateQuotationLine extends Mock implements UpdateQuotationLine {}

class _MockDeleteQuotationLineItem extends Mock
    implements DeleteQuotationLineItem {}

class _MockSetQuotationDiscounts extends Mock
    implements SetQuotationDiscounts {}

class _MockGetQuotationPreview extends Mock implements GetQuotationPreview {}

class _MockGetDepotAgreements extends Mock implements GetDepotAgreements {}

QuotationDetail _detail(String id, {List<QuotationLineItem> lines = const []}) {
  return QuotationDetail(
    id: id,
    number: 'QT-$id',
    depotId: 'cust-10',
    depotName: 'Depot Ten',
    status: 'Draft',
    statusGroup: QuotationStatusGroup.drafts,
    shipmentType: 'Pickup',
    currency: 'US3',
    revision: 1,
    requiredApprovalLevel: 0,
    lines: lines,
    totals: const QuotationTotals(
      currency: 'US3',
      gross: 0.0,
      discountTotal: 0.0,
      net: 0.0,
      isEstimate: false,
    ),
    createdAt: DateTime(2026, 9, 12),
  );
}

void main() {
  late _MockOpenQuotation mockOpen;
  late _MockGetQuotationDetail mockGetDetail;
  late _MockUpdateQuotationHeader mockUpdateHeader;
  late _MockAddQuotationLine mockAddLine;
  late _MockUpdateQuotationLine mockUpdateLine;
  late _MockDeleteQuotationLineItem mockDeleteLine;
  late _MockSetQuotationDiscounts mockSetDiscounts;
  late _MockGetQuotationPreview mockGetPreview;
  late _MockGetDepotAgreements mockGetAgreements;

  setUpAll(() {
    registerFallbackValue(const OpenQuotationParams(depotId: 'cust'));
    registerFallbackValue(const DepotAgreementsParams('cust'));
    registerFallbackValue(const QuotationIdParams('qt'));
    registerFallbackValue(const AddQuotationLineParams(
      id: 'qt',
      materialNumber: 'mat',
      quantity: 1,
    ));
    registerFallbackValue(const SetQuotationDiscountsParams(
      id: 'qt',
      lines: [],
    ));
    registerFallbackValue(
        const UpdateQuotationLineParams(id: 'qt', lineId: 'l', quantity: 1));
    registerFallbackValue(
        const DeleteQuotationLineParams(id: 'qt', lineId: 'l'));
  });

  setUp(() {
    mockOpen = _MockOpenQuotation();
    mockGetDetail = _MockGetQuotationDetail();
    mockUpdateHeader = _MockUpdateQuotationHeader();
    mockAddLine = _MockAddQuotationLine();
    mockUpdateLine = _MockUpdateQuotationLine();
    mockDeleteLine = _MockDeleteQuotationLineItem();
    mockSetDiscounts = _MockSetQuotationDiscounts();
    mockGetPreview = _MockGetQuotationPreview();
    mockGetAgreements = _MockGetDepotAgreements();
  });

  QuotationBuilderCubit build() => QuotationBuilderCubit(
        openQuotation: mockOpen,
        getQuotationDetail: mockGetDetail,
        updateQuotationHeader: mockUpdateHeader,
        addQuotationLine: mockAddLine,
        updateQuotationLine: mockUpdateLine,
        deleteQuotationLineItem: mockDeleteLine,
        setQuotationDiscounts: mockSetDiscounts,
        getQuotationPreview: mockGetPreview,
        getDepotAgreements: mockGetAgreements,
      );

  group('QuotationBuilderCubit', () {
    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'initializes by fetching depot agreements and opening quotation',
      build: () {
        when(() => mockGetAgreements(any())).thenAnswer(
          (_) async => const Success([
            DepotAgreement(
              id: 'agr-1',
              category: 'Roofing',
              percent: 2.5,
              kind: 'StandingDiscount',
              status: 'Active',
            ),
          ]),
        );
        when(() => mockOpen(any())).thenAnswer(
          (_) async => Success(_detail('qt-new')),
        );
        return build();
      },
      act: (cubit) => cubit.initialize(depotId: 'cust-10'),
      expect: () => [
        const QuotationBuilderLoading(),
        isA<QuotationBuilderReady>()
            .having((s) => s.quotation.id, 'id', 'qt-new')
            .having((s) => s.agreements.length, 'agreements length', 1)
            .having((s) => s.agreements.first.category, 'category', 'Roofing'),
      ],
    );

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'addLine updates quotation lines',
      build: () {
        when(() => mockAddLine(any())).thenAnswer(
          (_) async => Success(_detail('qt-new', lines: [
            const QuotationLineItem(
              id: 'line-1',
              lineNumber: 10,
              materialNumber: 'MAT-99',
              materialDescription: 'Pipe 2 inch',
              quantity: 10,
              unit: 'PC',
              priceAmount: 12.0,
              priceCurrency: 'US3',
              pricePricingUnit: 1,
              priceConditionUnit: 'PC',
              discounts: [],
              gross: 120.0,
              discountTotal: 0.0,
              net: 120.0,
            ),
          ])),
        );
        return build();
      },
      seed: () => QuotationBuilderReady(quotation: _detail('qt-new')),
      act: (cubit) => cubit.addLine(materialNumber: 'MAT-99', quantity: 10),
      expect: () => [
        isA<QuotationBuilderReady>()
            .having((s) => s.isMutating, 'isMutating true', true),
        isA<QuotationBuilderReady>()
            .having((s) => s.isMutating, 'isMutating false', false)
            .having((s) => s.quotation.lines.length, 'lines count', 1),
      ],
    );

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'setDiscounts updates discounts and emits ready state',
      build: () {
        when(() => mockSetDiscounts(any())).thenAnswer(
          (_) async => Success(_detail('qt-new')),
        );
        return build();
      },
      seed: () => QuotationBuilderReady(quotation: _detail('qt-new')),
      act: (cubit) => cubit.setDiscounts([
        const QuotationDiscountIntent(lineId: 'line-1', percent: 5.0),
      ]),
      expect: () => [
        isA<QuotationBuilderReady>()
            .having((s) => s.isMutating, 'isMutating true', true),
        isA<QuotationBuilderReady>()
            .having((s) => s.isMutating, 'isMutating false', false),
      ],
    );
  });

  group('syncLineQuantity', () {
    const line = QuotationLineItem(
      id: 'line-1',
      lineNumber: 10,
      materialNumber: 'MAT-99',
      materialDescription: 'Pipe 2 inch',
      quantity: 10,
      unit: 'PC',
      priceAmount: 12.0,
      priceCurrency: 'US3',
      pricePricingUnit: 1,
      priceConditionUnit: 'PC',
      discounts: [],
      gross: 120.0,
      discountTotal: 0.0,
      net: 120.0,
    );
    QuotationBuilderReady withLine() =>
        QuotationBuilderReady(quotation: _detail('qt-1', lines: const [line]));

    setUp(() {
      when(() => mockAddLine(any()))
          .thenAnswer((_) async => Success(_detail('qt-1')));
      when(() => mockUpdateLine(any()))
          .thenAnswer((_) async => Success(_detail('qt-1')));
      when(() => mockDeleteLine(any()))
          .thenAnswer((_) async => Success(_detail('qt-1')));
    });

    void verifyNoLineCalls() {
      verifyNever(() => mockAddLine(any()));
      verifyNever(() => mockUpdateLine(any()));
      verifyNever(() => mockDeleteLine(any()));
    }

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'does nothing before the draft is open',
      build: build,
      act: (cubit) =>
          cubit.syncLineQuantity(materialNumber: 'MAT-99', quantity: 3),
      expect: () => <QuotationBuilderState>[],
      verify: (_) => verifyNoLineCalls(),
    );

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'zero on an existing line deletes it',
      build: build,
      seed: withLine,
      act: (cubit) =>
          cubit.syncLineQuantity(materialNumber: 'MAT-99', quantity: 0),
      verify: (_) {
        final p = verify(() => mockDeleteLine(captureAny())).captured.single
            as DeleteQuotationLineParams;
        expect(p.lineId, 'line-1');
        verifyNever(() => mockUpdateLine(any()));
      },
    );

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'a new quantity on an existing line updates it',
      build: build,
      seed: withLine,
      act: (cubit) => cubit.syncLineQuantity(
          materialNumber: 'MAT-99', quantity: 3, unit: 'PC'),
      verify: (_) {
        final p = verify(() => mockUpdateLine(captureAny())).captured.single
            as UpdateQuotationLineParams;
        expect(p.lineId, 'line-1');
        expect(p.quantity, 3.0);
        expect(p.unit, 'PC');
        verifyNever(() => mockAddLine(any()));
      },
    );

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'a positive quantity for a new material adds a line',
      build: build,
      seed: withLine,
      act: (cubit) => cubit.syncLineQuantity(
          materialNumber: 'MAT-1', quantity: 2, unit: 'sheet'),
      verify: (_) {
        final p = verify(() => mockAddLine(captureAny())).captured.single
            as AddQuotationLineParams;
        expect(p.materialNumber, 'MAT-1');
        expect(p.quantity, 2.0);
        expect(p.unit, 'sheet');
      },
    );

    blocTest<QuotationBuilderCubit, QuotationBuilderState>(
      'zero for a material not on the draft does nothing',
      build: build,
      seed: withLine,
      act: (cubit) =>
          cubit.syncLineQuantity(materialNumber: 'MAT-1', quantity: 0),
      expect: () => <QuotationBuilderState>[],
      verify: (_) => verifyNoLineCalls(),
    );
  });
}
