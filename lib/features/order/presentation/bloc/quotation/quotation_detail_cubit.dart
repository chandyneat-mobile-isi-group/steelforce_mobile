import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_state.dart';

class QuotationDetailCubit extends Cubit<QuotationDetailState> {
  QuotationDetailCubit({
    required GetQuotationDetail getQuotationDetail,
    required SubmitQuotation submitQuotation,
    required RepriceQuotation repriceQuotation,
    required CancelQuotation cancelQuotation,
    required GetQuotationHistory getQuotationHistory,
  })  : _getQuotationDetail = getQuotationDetail,
        _submitQuotation = submitQuotation,
        _repriceQuotation = repriceQuotation,
        _cancelQuotation = cancelQuotation,
        _getQuotationHistory = getQuotationHistory,
        super(const QuotationDetailInitial());

  final GetQuotationDetail _getQuotationDetail;
  final SubmitQuotation _submitQuotation;
  final RepriceQuotation _repriceQuotation;
  final CancelQuotation _cancelQuotation;
  final GetQuotationHistory _getQuotationHistory;

  Future<void> load(String id) async {
    emit(const QuotationDetailLoading());

    final detailResult = await _getQuotationDetail(QuotationIdParams(id));
    await detailResult.when(
      success: (detail) async {
        final historyResult = await _getQuotationHistory(QuotationIdParams(id));
        final history = historyResult.when(
          success: (h) => h,
          failure: (_) => const <QuotationApprovalHistory>[],
        );
        emit(QuotationDetailLoaded(quotation: detail, history: history));
      },
      failure: (failure) {
        emit(QuotationDetailError(failure.message));
      },
    );
  }

  Future<void> submit() async {
    final current = state;
    if (current is! QuotationDetailLoaded &&
        current is! QuotationDetailPriceChanged) {
      return;
    }

    final quotation = current is QuotationDetailLoaded
        ? current.quotation
        : (current as QuotationDetailPriceChanged).quotation;

    if (current is QuotationDetailLoaded) {
      emit(current.copyWith(isSubmitting: true, actionMessage: () => null));
    }

    final result = await _submitQuotation(QuotationIdParams(quotation.id));
    result.when(
      success: (updated) {
        final history = current is QuotationDetailLoaded
            ? current.history
            : const <QuotationApprovalHistory>[];
        emit(QuotationDetailLoaded(
          quotation: updated,
          history: history,
          isSubmitting: false,
          actionMessage: 'Quotation submitted for approval.',
        ));
      },
      failure: (failure) {
        if (failure is ServerFailure &&
            failure.code == 'Quotation.PriceChanged') {
          emit(QuotationDetailPriceChanged(
            quotation: quotation,
            message: failure.message,
          ));
          return;
        }

        if (current is QuotationDetailLoaded) {
          emit(current.copyWith(
            isSubmitting: false,
            actionMessage: () => failure.message,
          ));
        } else {
          emit(QuotationDetailError(failure.message));
        }
      },
    );
  }

  Future<void> reprice() async {
    final current = state;
    final quotation = current is QuotationDetailLoaded
        ? current.quotation
        : current is QuotationDetailPriceChanged
            ? current.quotation
            : null;

    if (quotation == null) return;

    if (current is QuotationDetailLoaded) {
      emit(current.copyWith(isRepricing: true, actionMessage: () => null));
    } else {
      emit(QuotationDetailLoaded(
        quotation: quotation,
        isRepricing: true,
      ));
    }

    final result = await _repriceQuotation(QuotationIdParams(quotation.id));
    result.when(
      success: (updated) {
        final history = current is QuotationDetailLoaded
            ? current.history
            : const <QuotationApprovalHistory>[];
        emit(QuotationDetailLoaded(
          quotation: updated,
          history: history,
          isRepricing: false,
          actionMessage: 'Prices updated from SAP.',
        ));
      },
      failure: (failure) {
        if (current is QuotationDetailLoaded) {
          emit(current.copyWith(
            isRepricing: false,
            actionMessage: () => failure.message,
          ));
        } else {
          emit(QuotationDetailError(failure.message));
        }
      },
    );
  }

  Future<void> cancel() async {
    final current = state;
    if (current is! QuotationDetailLoaded) return;

    emit(current.copyWith(isCancelling: true, actionMessage: () => null));

    final result =
        await _cancelQuotation(QuotationIdParams(current.quotation.id));
    result.when(
      success: (updated) {
        emit(current.copyWith(
          quotation: updated,
          isCancelling: false,
          actionMessage: () => 'Quotation cancelled.',
        ));
      },
      failure: (failure) {
        emit(current.copyWith(
          isCancelling: false,
          actionMessage: () => failure.message,
        ));
      },
    );
  }
}
