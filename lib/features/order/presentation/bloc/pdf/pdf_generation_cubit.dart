import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';

import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/pdf/storage/pdf_file_service.dart';
import 'package:steelforce/core/pdf/pdf_service.dart';
import 'package:steelforce/core/pdf/sharing/pdf_share_service.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/pdf/quotation_pdf_data.dart';
import 'package:steelforce/features/order/pdf/quotation_pdf_generator.dart';
import 'package:steelforce/features/order/presentation/bloc/pdf/pdf_generation_state.dart';

/// Orchestrates the export pipeline for document PDFs: build bytes → save to the
/// app sandbox → present preview/print/share. Holds no PDF layout logic itself
/// (that lives in the feature generators) and never touches widgets — the UI
/// only reads its states.
///
/// Extensible by design: adding `generateInvoicePdf(...)` later means mapping to
/// an `InvoicePdfData` and swapping in an `InvoicePdfGenerator`; the save/share
/// tail is identical and reused.
class PdfGenerationCubit extends Cubit<PdfGenerationState> {
  PdfGenerationCubit({
    required PdfService pdfService,
    required PdfFileService fileService,
    required PdfShareService shareService,
    required SessionManager session,
    AppLogger? logger,
  })  : _pdfService = pdfService,
        _fileService = fileService,
        _shareService = shareService,
        _session = session,
        _logger = logger,
        super(const PdfInitial());

  final PdfService _pdfService;
  final PdfFileService _fileService;
  final PdfShareService _shareService;
  final SessionManager _session;
  final AppLogger? _logger;

  /// Generates the quotation PDF from live cart data, saves it, then opens the
  /// native preview/print/share sheet. The sales rep is resolved from the
  /// signed-in session here (a domain concern) so the calling widget stays
  /// free of session lookups.
  Future<void> generateQuotationPdf({
    required String quotationNumber,
    required String depotName,
    required DateTime createdDate,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    double? skuDiscountTotal,
    double? invoiceDiscountTotal,
    required double tax,
    required double total,
    bool isTaxApplicable = true,
    List<String> invoiceDiscounts = const [],
    String? depotPhone,
    String? depotAddress,
    String? depotEmail,
    String? companyName,
    String? contactPerson,
    String? salesTerritory,
    DateTime? validUntil,
    String? paymentTerms,
    String? deliveryTerms,
    String? deliveryLocation,
    String? estimatedDelivery,
    double deliveryFee = 0.0,
    String? notes,
  }) async {
    if (isClosed) return;
    emit(const PdfGenerating());

    try {
      final user = _session.currentUser;
      final data = QuotationPdfData.fromCart(
        quotationNumber: quotationNumber,
        depotName: depotName,
        depotPhone: depotPhone,
        depotAddress: depotAddress,
        depotEmail: depotEmail,
        companyName: companyName,
        contactPerson: contactPerson,
        salesRepName: user?.fullName ?? 'app.title'.tr,
        salesRepContact: user?.email,
        salesTerritory: salesTerritory,
        createdDate: createdDate,
        validUntil: validUntil,
        paymentTerms: paymentTerms,
        deliveryTerms: deliveryTerms,
        deliveryLocation: deliveryLocation,
        estimatedDelivery: estimatedDelivery,
        deliveryFee: deliveryFee,
        items: items,
        subtotal: subtotal,
        discount: discount,
        skuDiscountTotal: skuDiscountTotal,
        invoiceDiscountTotal: invoiceDiscountTotal,
        tax: tax,
        total: total,
        isTaxApplicable: isTaxApplicable,
        invoiceDiscounts: invoiceDiscounts,
        notes: notes,
      );

      final generator = QuotationPdfGenerator(data);
      final bytes = await _pdfService.generate(generator);
      final document = await _fileService.save(bytes,
          fileNamePrefix: generator.documentName);

      if (isClosed) return;
      // Surface success immediately so the UI can confirm; the preview sheet is
      // an interactive follow-up, not part of the success signal.
      emit(PdfGenerated(document));

      await _shareService.previewAndPrint(
        bytes,
        documentName: '${generator.documentName} $quotationNumber',
      );
    } catch (error, stackTrace) {
      // No PII in the event name/fields per SECURITY.md §10; the exception is
      // redacted by the logger. Never log depot names or prices.
      _logger?.error(
        'pdf_generation_failed',
        error: error,
        stackTrace: stackTrace,
        fields: {'doc': 'quotation'},
      );
      if (isClosed) return;
      emit(const PdfGenerationFailed('orders.quotation.pdf.error'));
    }
  }

  /// Re-presents the last generated document — the platform viewer on mobile,
  /// a download on web.
  Future<void> openSaved() async {
    final current = state;
    if (current is PdfGenerated) {
      await _shareService.openSaved(current.document);
    }
  }
}
