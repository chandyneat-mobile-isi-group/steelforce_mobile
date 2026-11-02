import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/get_quotation_by_id.dart';

sealed class PendingQuotationDetailsState extends Equatable {
  const PendingQuotationDetailsState();

  @override
  List<Object?> get props => [];
}

class PendingQuotationDetailsLoading extends PendingQuotationDetailsState {
  const PendingQuotationDetailsLoading();
}

class PendingQuotationDetailsLoaded extends PendingQuotationDetailsState {
  const PendingQuotationDetailsLoaded(this.quotation);
  final Quotation quotation;

  @override
  List<Object?> get props => [quotation];
}

/// The queue still lists it, but the device copy is gone (discarded from
/// another screen, or a cleared session). Not an error: there is simply
/// nothing local to show.
class PendingQuotationDetailsNotFound extends PendingQuotationDetailsState {
  const PendingQuotationDetailsNotFound();
}

class PendingQuotationDetailsFailure extends PendingQuotationDetailsState {
  const PendingQuotationDetailsFailure();
}

/// Reads the device copy of a quotation waiting in the sync queue, so the
/// Sync Center can show what will be sent — lines, quantities, totals —
/// without a network round trip.
class PendingQuotationDetailsCubit extends Cubit<PendingQuotationDetailsState> {
  PendingQuotationDetailsCubit(this._get)
      : super(const PendingQuotationDetailsLoading());

  final GetQuotationById _get;

  Future<void> load(String quotationId) async {
    emit(const PendingQuotationDetailsLoading());
    final result = await _get(QuotationIdParams(quotationId));
    if (isClosed) return;
    emit(result.when(
      success: (q) => q == null
          ? const PendingQuotationDetailsNotFound()
          : PendingQuotationDetailsLoaded(q),
      failure: (_) => const PendingQuotationDetailsFailure(),
    ));
  }
}
