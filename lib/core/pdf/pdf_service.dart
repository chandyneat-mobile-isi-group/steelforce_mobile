import 'dart:typed_data';

import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/pdf/document/pdf_assets.dart';
import 'package:steelforce/core/pdf/document/pdf_document_builder.dart';
import 'package:steelforce/core/pdf/document/pdf_theme.dart';

/// Renders any [PdfDocumentBuilder] into PDF bytes.
///
/// This is the single, feature-agnostic entry point for PDF generation across
/// the CRM: it owns shared concerns (font/logo loading, theme, active locale)
/// and delegates the actual layout to the feature's generator. Callers pass a
/// generator, get back bytes — nothing here knows what a quotation is.
abstract class PdfService {
  Future<Uint8List> generate(PdfDocumentBuilder builder);
}

class PdfServiceImpl implements PdfService {
  PdfServiceImpl(this._assets, {PdfTheme theme = const PdfTheme()})
      : _theme = theme;

  final PdfAssets _assets;
  final PdfTheme _theme;

  @override
  Future<Uint8List> generate(PdfDocumentBuilder builder) async {
    await _assets.ensureLoaded();

    final context = PdfBuildContext(
      assets: _assets,
      theme: _theme,
      languageCode: LocalizationService.instance.currentLanguageCode,
    );

    final document = await builder.build(context);
    // `save()` is CPU-bound but fast for typical documents; the surrounding
    // Cubit keeps the whole call off the build/paint path via async.
    return document.save();
  }
}
