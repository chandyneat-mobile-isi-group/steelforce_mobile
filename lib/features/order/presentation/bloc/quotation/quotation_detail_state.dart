import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

sealed class QuotationDetailState extends Equatable {
  const QuotationDetailState();

  @override
  List<Object?> get props => [];
}

final class QuotationDetailInitial extends QuotationDetailState {
  const QuotationDetailInitial();
}

final class QuotationDetailLoading extends QuotationDetailState {
  const QuotationDetailLoading();
}

final class QuotationDetailLoaded extends QuotationDetailState {
  const QuotationDetailLoaded({
    required this.quotation,
    this.history = const [],
    this.isSubmitting = false,
    this.isCancelling = false,
    this.isRepricing = false,
    this.actionMessage,
  });

  final QuotationDetail quotation;
  final List<QuotationApprovalHistory> history;
  final bool isSubmitting;
  final bool isCancelling;
  final bool isRepricing;
  final String? actionMessage;

  QuotationDetailLoaded copyWith({
    QuotationDetail? quotation,
    List<QuotationApprovalHistory>? history,
    bool? isSubmitting,
    bool? isCancelling,
    bool? isRepricing,
    String? Function()? actionMessage,
  }) {
    return QuotationDetailLoaded(
      quotation: quotation ?? this.quotation,
      history: history ?? this.history,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCancelling: isCancelling ?? this.isCancelling,
      isRepricing: isRepricing ?? this.isRepricing,
      actionMessage:
          actionMessage != null ? actionMessage() : this.actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        quotation,
        history,
        isSubmitting,
        isCancelling,
        isRepricing,
        actionMessage,
      ];
}

/// Emitted when POST .../submit responds with 409 Quotation.PriceChanged.
final class QuotationDetailPriceChanged extends QuotationDetailState {
  const QuotationDetailPriceChanged({
    required this.quotation,
    required this.message,
  });

  final QuotationDetail quotation;
  final String message;

  @override
  List<Object?> get props => [quotation, message];
}

final class QuotationDetailError extends QuotationDetailState {
  const QuotationDetailError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
