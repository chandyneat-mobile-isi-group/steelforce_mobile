import 'package:equatable/equatable.dart';
import 'package:steelforce/core/pdf/storage/saved_document.dart';

/// State of a single PDF export attempt. Owned by [PdfGenerationCubit];
/// document-type agnostic so the same states drive quotation, invoice, and
/// report exports.
abstract class PdfGenerationState extends Equatable {
  const PdfGenerationState();

  @override
  List<Object?> get props => [];
}

/// Idle — nothing generated yet in this screen.
class PdfInitial extends PdfGenerationState {
  const PdfInitial();
}

/// Bytes are being built and written. UI shows a blocking-free spinner.
class PdfGenerating extends PdfGenerationState {
  const PdfGenerating();
}

/// The document was generated and the preview/share sheet was offered.
///
/// [document] holds the PDF bytes and, on mobile, the sandbox path it was
/// written to. On web nothing is on disk — check [SavedDocument.isOnDisk]
/// before telling the user the file was saved.
class PdfGenerated extends PdfGenerationState {
  const PdfGenerated(this.document);

  final SavedDocument document;

  @override
  List<Object?> get props => [document];
}

/// Generation failed. [messageKey] is a localization key (already resolvable
/// via `.tr`) suitable for a snackbar.
class PdfGenerationFailed extends PdfGenerationState {
  const PdfGenerationFailed(this.messageKey);

  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}
