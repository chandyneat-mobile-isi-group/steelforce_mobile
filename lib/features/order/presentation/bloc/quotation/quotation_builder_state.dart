import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';

sealed class QuotationBuilderState extends Equatable {
  const QuotationBuilderState();

  @override
  List<Object?> get props => [];
}

final class QuotationBuilderInitial extends QuotationBuilderState {
  const QuotationBuilderInitial();
}

final class QuotationBuilderLoading extends QuotationBuilderState {
  const QuotationBuilderLoading();
}

final class QuotationBuilderReady extends QuotationBuilderState {
  const QuotationBuilderReady({
    required this.quotation,
    this.preview,
    this.agreements = const [],
    this.discountAuthority,
    this.isMutating = false,
    this.isDebouncingPreview = false,
    this.errorMessage,
    this.noticeMessage,
  });

  final QuotationDetail quotation;
  final QuotationPreviewData? preview;
  final List<DepotAgreement> agreements;
  final DiscountAuthority? discountAuthority;
  final bool isMutating;
  final bool isDebouncingPreview;
  final String? errorMessage;
  final String? noticeMessage;

  /// Prefer preview totals over snapshot totals if available.
  QuotationTotals get effectiveTotals => preview?.totals ?? quotation.totals;

  List<QuotationLineItem> get effectiveLines =>
      preview?.lines ?? quotation.lines;

  double get manualDiscountLimit =>
      preview?.manualDiscountLimitPercent ??
      discountAuthority?.maxManualDiscountPercent ??
      10.0;

  double get lineDiscountCap =>
      preview?.lineDiscountCapPercent ??
      discountAuthority?.lineDiscountCapPercent ??
      15.0;

  int get requiredApprovalLevel =>
      preview?.requiredApprovalLevel ?? quotation.requiredApprovalLevel;

  List<QuotationWarning> get warnings => preview?.warnings ?? const [];

  /// The server line for [materialNumber] on the saved draft, or null. Lines
  /// are matched by material because the cart knows nothing of server ids.
  QuotationLineItem? lineForMaterial(String materialNumber) {
    for (final line in quotation.lines) {
      if (line.materialNumber == materialNumber) return line;
    }
    return null;
  }

  QuotationBuilderReady copyWith({
    QuotationDetail? quotation,
    QuotationPreviewData? Function()? preview,
    List<DepotAgreement>? agreements,
    DiscountAuthority? discountAuthority,
    bool? isMutating,
    bool? isDebouncingPreview,
    String? Function()? errorMessage,
    String? Function()? noticeMessage,
  }) {
    return QuotationBuilderReady(
      quotation: quotation ?? this.quotation,
      preview: preview != null ? preview() : this.preview,
      agreements: agreements ?? this.agreements,
      discountAuthority: discountAuthority ?? this.discountAuthority,
      isMutating: isMutating ?? this.isMutating,
      isDebouncingPreview: isDebouncingPreview ?? this.isDebouncingPreview,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      noticeMessage:
          noticeMessage != null ? noticeMessage() : this.noticeMessage,
    );
  }

  @override
  List<Object?> get props => [
        quotation,
        preview,
        agreements,
        discountAuthority,
        isMutating,
        isDebouncingPreview,
        errorMessage,
        noticeMessage,
      ];
}

final class QuotationBuilderError extends QuotationBuilderState {
  const QuotationBuilderError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
