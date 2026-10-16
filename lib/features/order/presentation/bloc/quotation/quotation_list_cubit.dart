import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_list_state.dart';

class QuotationListCubit extends Cubit<QuotationListState> {
  QuotationListCubit({required GetQuotationsList getQuotationsList})
      : _getQuotationsList = getQuotationsList,
        super(const QuotationListInitial());

  final GetQuotationsList _getQuotationsList;

  Future<void> load({
    QuotationStatusGroup? group,
    String? depotId,
    bool refresh = false,
  }) async {
    final current = state;
    if (current is QuotationListLoaded && refresh) {
      emit(current.copyWith(isRefreshing: true));
    } else if (current is! QuotationListLoaded) {
      emit(const QuotationListLoading());
    }

    final targetGroup = group ??
        (current is QuotationListLoaded ? current.selectedGroup : null);
    final targetDepot =
        depotId ?? (current is QuotationListLoaded ? current.depotId : null);

    final result = await _getQuotationsList(GetQuotationsParams(
      status: targetGroup?.wireName,
      depotId: targetDepot,
      page: 1,
      pageSize: 20,
    ));

    result.when(
      success: (paged) {
        emit(QuotationListLoaded(
          quotations: paged.items,
          selectedGroup: targetGroup,
          page: 1,
          hasMore: paged.hasMore,
          depotId: targetDepot,
          isRefreshing: false,
        ));
      },
      failure: (failure) {
        emit(QuotationListError(failure.message));
      },
    );
  }

  Future<void> selectGroup(QuotationStatusGroup? group) async {
    final current = state;
    final depotId = current is QuotationListLoaded ? current.depotId : null;
    await load(group: group, depotId: depotId);
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! QuotationListLoaded ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.isRefreshing) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    final nextPage = current.page + 1;

    final result = await _getQuotationsList(GetQuotationsParams(
      status: current.selectedGroup?.wireName,
      depotId: current.depotId,
      page: nextPage,
      pageSize: 20,
    ));

    result.when(
      success: (paged) {
        emit(current.copyWith(
          quotations: [...current.quotations, ...paged.items],
          page: nextPage,
          hasMore: paged.hasMore,
          isLoadingMore: false,
        ));
      },
      failure: (_) {
        emit(current.copyWith(isLoadingMore: false));
      },
    );
  }
}
