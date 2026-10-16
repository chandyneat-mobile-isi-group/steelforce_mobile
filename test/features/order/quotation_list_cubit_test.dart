import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_list_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_list_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetQuotationsList extends Mock implements GetQuotationsList {}

QuotationSummary _summary(String id, QuotationStatusGroup group) {
  return QuotationSummary(
    id: id,
    number: 'QT-$id',
    depotId: 'cust-1',
    depotName: 'Depot One',
    status: 'Draft',
    statusGroup: group,
    currency: 'US3',
    net: 500.0,
    lineCount: 2,
    createdAt: DateTime(2026, 9, 12),
  );
}

void main() {
  late _MockGetQuotationsList mockGetQuotationsList;

  setUpAll(() {
    registerFallbackValue(const GetQuotationsParams());
  });

  setUp(() {
    mockGetQuotationsList = _MockGetQuotationsList();
  });

  group('QuotationListCubit', () {
    blocTest<QuotationListCubit, QuotationListState>(
      'loads initial quotations successfully',
      build: () {
        when(() => mockGetQuotationsList(any())).thenAnswer(
          (_) async => Success(
            PagedResult<QuotationSummary>(
              items: [
                _summary('1', QuotationStatusGroup.drafts),
                _summary('2', QuotationStatusGroup.drafts),
              ],
              page: 1,
              hasMore: false,
            ),
          ),
        );
        return QuotationListCubit(getQuotationsList: mockGetQuotationsList);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const QuotationListLoading(),
        isA<QuotationListLoaded>()
            .having((s) => s.quotations.length, 'length', 2)
            .having((s) => s.page, 'page', 1)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<QuotationListCubit, QuotationListState>(
      'filters by status group when selectGroup is called',
      build: () {
        when(() => mockGetQuotationsList(any())).thenAnswer(
          (_) async => Success(
            PagedResult<QuotationSummary>(
              items: [
                _summary('3', QuotationStatusGroup.waiting),
              ],
              page: 1,
              hasMore: false,
            ),
          ),
        );
        return QuotationListCubit(getQuotationsList: mockGetQuotationsList);
      },
      act: (cubit) => cubit.selectGroup(QuotationStatusGroup.waiting),
      expect: () => [
        const QuotationListLoading(),
        isA<QuotationListLoaded>()
            .having((s) => s.selectedGroup, 'selectedGroup',
                QuotationStatusGroup.waiting)
            .having((s) => s.quotations.first.statusGroup, 'group',
                QuotationStatusGroup.waiting),
      ],
      verify: (_) {
        verify(() => mockGetQuotationsList(any(
              that: isA<GetQuotationsParams>().having(
                (p) => p.status,
                'status',
                'Waiting',
              ),
            ))).called(1);
      },
    );

    blocTest<QuotationListCubit, QuotationListState>(
      'emits QuotationListError on failure',
      build: () {
        when(() => mockGetQuotationsList(any())).thenAnswer(
          (_) async => const Failed(
            ServerFailure(message: 'Failed to connect to ISI server'),
          ),
        );
        return QuotationListCubit(getQuotationsList: mockGetQuotationsList);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const QuotationListLoading(),
        const QuotationListError('Failed to connect to ISI server'),
      ],
    );
  });
}
