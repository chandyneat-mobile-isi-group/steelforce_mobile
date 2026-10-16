import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads and **caches** the fonts and imagery every ISI PDF needs, so the
/// (relatively expensive) asset-bundle reads happen once per app session
/// rather than on every export.
///
/// Registered as a lazy singleton in DI; [ensureLoaded] is idempotent and safe
/// to call before each generation.
///
/// Font strategy — bilingual rendering:
/// - Latin (English UI) is drawn with **Source Sans 3**.
/// - Khmer Unicode has no glyphs in Source Sans 3, so **MiSans Khmer** is supplied
///   as a [pw.ThemeData.fontFallback]; the PDF engine automatically falls back
///   glyph-by-glyph, which is what makes mixed "ISI Steel / ខ្មែរ" strings
///   render correctly in a single run.
///
/// Both families are loaded from static `.ttf` files: [pw.Font.ttf] parses the
/// `glyf` table only, so neither MiSans' CFF `.otf` drop nor Source Sans 3's
/// variable font can be read here. See the `fonts:` note in `pubspec.yaml`.
class PdfAssets {
  PdfAssets();

  pw.Font? _base;
  pw.Font? _bold;
  pw.Font? _khmer;
  pw.Font? _khmerBold;
  String? _logoSvg;
  bool _loaded = false;

  pw.Font get base => _base!;
  pw.Font get bold => _bold!;
  pw.Font get khmer => _khmer!;
  pw.Font get khmerBold => _khmerBold!;

  /// The ISI Group wordmark as raw SVG source, or `null` if the asset could
  /// not be read (the generator degrades gracefully to a text wordmark).
  ///
  /// Vector rather than a bitmap: a quotation is printed and re-scaled by
  /// whoever receives it, which is precisely where a 34pt bitmap header shows
  /// its pixels.
  ///
  /// `isi-steel-dark.svg` — the **navy** (`#011E41`) mark — is the only correct
  /// one here: a PDF is drawn on white paper. Loading `isi-steel-light.svg`
  /// would emit a near-white wordmark onto white, and the header would come out
  /// blank on a document that still saves and still reaches the depot.
  String? get logoSvg => _logoSvg;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    _base = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/english/Source_Sans_3/static/SourceSans3-Regular.ttf',
      ),
    );
    _bold = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/english/Source_Sans_3/static/SourceSans3-Bold.ttf',
      ),
    );
    _khmer = pw.Font.ttf(
      await rootBundle.load('assets/fonts/khmer/MiSansKhmer-Regular.ttf'),
    );
    _khmerBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/khmer/MiSansKhmer-Bold.ttf'),
    );

    try {
      _logoSvg = await rootBundle.loadString('assets/logos/isi-steel-dark.svg');
    } catch (_) {
      // Missing/renamed logo must never fail an export — fall back to wordmark.
      _logoSvg = null;
    }

    _loaded = true;
  }

  /// The base document theme: Source Sans 3 for Latin, MiSans Khmer as glyph
  /// fallback for Khmer across both regular and bold weights.
  pw.ThemeData buildTheme() => pw.ThemeData.withFont(
        base: _base!,
        bold: _bold!,
        fontFallback: [_khmer!, _khmerBold!],
      );
}
