import 'package:pdf/widgets.dart' as pw;

import 'package:steelforce/core/pdf/document/pdf_assets.dart';
import 'package:steelforce/core/pdf/document/pdf_theme.dart';

/// Everything a feature generator needs to lay out a document, assembled once
/// by [PdfService] and handed in. Generators read shared fonts/logo/theme from
/// here instead of touching the asset bundle themselves — that keeps asset
/// loading centralized, cached, and testable.
class PdfBuildContext {
  const PdfBuildContext({
    required this.assets,
    required this.theme,
    required this.languageCode,
  });

  final PdfAssets assets;
  final PdfTheme theme;

  /// Active app locale (`en` / `kh`), so a generator can pick date/number
  /// formats or a document title per language.
  final String languageCode;

  /// The base [pw.ThemeData] (Inter + Khmer fallback) for the whole document.
  pw.ThemeData get pdfTheme => assets.buildTheme();
}

/// The contract every document generator implements — quotation today,
/// invoice / visit report / depot report / sales report / stock report
/// tomorrow. Implementations must stay **free of Flutter widgets and of any
/// BLoC/UI state**: they receive a plain, already-mapped data object and emit a
/// [pw.Document]. That is what lets the same generator run on the main isolate,
/// a background isolate, or a unit test unchanged.
abstract class PdfDocumentBuilder {
  const PdfDocumentBuilder();

  /// Human-readable job name used for the native print/preview sheet and as the
  /// saved-file prefix, e.g. `ISI_Quotation`.
  String get documentName;

  Future<pw.Document> build(PdfBuildContext context);
}
