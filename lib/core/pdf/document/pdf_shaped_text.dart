import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:steelforce/core/theme/app_typography.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders text for PDF documents with **correct complex-script shaping**.
///
/// The dart `pdf` engine maps codepoints to glyphs one-by-one (no GSUB/GPOS),
/// which draws Khmer subscript consonants (ជើង) and pre-base vowels in the
/// wrong visual order — unreadable output no font can fix. Flutter's own text
/// engine (HarfBuzz) shapes Khmer perfectly, so this helper routes any string
/// containing Khmer through `dart:ui`: the text is laid out and rasterized at
/// [scale]× resolution (print-crisp) and embedded as an image sized to the
/// exact point dimensions vector text would have occupied. Latin-only strings
/// fall through to normal vector [pw.Text] — English documents are unchanged.
///
/// ## Usage — two-pass build
///
/// Rasterization is async but `pw.MultiPage` builders are synchronous, so a
/// generator uses two passes:
///
/// 1. Build its widget tree once and discard it — every [text] call whose
///    string needs shaping records a pending request and returns a fallback.
/// 2. `await warmPending()` — all requests render to images.
/// 3. Build the real page: every [text] call now hits the cache.
class PdfShapedText {
  PdfShapedText({
    this.scale = 6.0,
    this.fontFamily = AppTypography.khmerFontFamily,
  });

  /// Raster supersampling factor: glyphs render at `fontSize × scale` px and
  /// display at `fontSize` pt, keeping print output sharp.
  final double scale;

  /// Flutter-registered font family used to shape/rasterize (must ship the
  /// script's glyphs — MiSans Khmer for Khmer, per pubspec `fonts:`).
  final String fontFamily;

  static final RegExp _khmer = RegExp(r'[ក-៿᧠-᧿]');

  /// Whether [text] contains codepoints the PDF engine cannot shape.
  static bool needsShaping(String text) => _khmer.hasMatch(text);

  final Map<String, _ShapedImage> _cache = {};
  final Map<String, _Request> _pending = {};

  /// Returns a widget for [text]: vector [pw.Text] when the engine can render
  /// it directly, a pre-rasterized image when it needs shaping. Unrendered
  /// shaped strings are recorded for [warmPending] and temporarily fall back
  /// to vector text (pass 1 of the two-pass build).
  pw.Widget text(
    String text, {
    required double fontSize,
    required PdfColor color,
    bool bold = false,
    double letterSpacing = 0,
    double lineSpacing = 0,
    double? maxWidth,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      letterSpacing: letterSpacing,
      lineSpacing: lineSpacing,
    );
    if (text.isEmpty || !needsShaping(text)) return pw.Text(text, style: style);

    final key = _key(text, fontSize, bold, color, letterSpacing, maxWidth);
    final cached = _cache[key];
    if (cached != null) {
      return pw.Image(
        pw.MemoryImage(cached.png),
        width: cached.width,
        height: cached.height,
      );
    }

    _pending[key] = _Request(
        text, fontSize, bold, color, letterSpacing, lineSpacing, maxWidth);
    return pw.Text(text, style: style);
  }

  /// Rasterizes every string recorded by [text] since the last warm. Failures
  /// are swallowed per-string — a raster problem must never break an export;
  /// the affected string simply falls back to vector text.
  Future<void> warmPending() async {
    final requests = Map.of(_pending);
    _pending.clear();
    for (final entry in requests.entries) {
      try {
        _cache[entry.key] = await _rasterize(entry.value);
      } catch (_) {
        // Fallback to vector text for this string only.
      }
    }
  }

  Future<_ShapedImage> _rasterize(_Request r) async {
    final pxSize = r.fontSize * scale;
    final maxPxWidth = (r.maxWidth ?? 4000) * scale;

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        fontFamily: fontFamily,
        fontSize: pxSize,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: _uiColor(r.color),
        fontSize: pxSize,
        fontFamily: fontFamily,
        fontFamilyFallback: const [AppTypography.latinFontFamily],
        fontWeight: r.bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
        letterSpacing: r.letterSpacing * scale,
        // Approximates pdf's `lineSpacing` (extra pts between lines).
        height: r.lineSpacing > 0
            ? (r.fontSize + r.lineSpacing) / r.fontSize
            : null,
      ))
      ..addText(r.text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxPxWidth));

    final pxWidth = paragraph.longestLine.ceilToDouble().clamp(1, maxPxWidth);
    final pxHeight = paragraph.height.ceilToDouble().clamp(1, 100000);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
    final image = await recorder
        .endRecording()
        .toImage(pxWidth.toInt(), pxHeight.toInt());
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('PNG encode failed for shaped PDF text');
      }
      return _ShapedImage(
        png: byteData.buffer.asUint8List(),
        width: pxWidth / scale,
        height: pxHeight / scale,
      );
    } finally {
      image.dispose();
    }
  }

  static ui.Color _uiColor(PdfColor c) => ui.Color.fromARGB(
        (c.alpha * 255).round(),
        (c.red * 255).round(),
        (c.green * 255).round(),
        (c.blue * 255).round(),
      );

  static String _key(String text, double size, bool bold, PdfColor color,
          double letterSpacing, double? maxWidth) =>
      '$text|$size|$bold|${color.toInt()}|$letterSpacing|$maxWidth';
}

class _Request {
  const _Request(this.text, this.fontSize, this.bold, this.color,
      this.letterSpacing, this.lineSpacing, this.maxWidth);
  final String text;
  final double fontSize;
  final bool bold;
  final PdfColor color;
  final double letterSpacing;
  final double lineSpacing;
  final double? maxWidth;
}

class _ShapedImage {
  const _ShapedImage(
      {required this.png, required this.width, required this.height});
  final Uint8List png;
  final double width;
  final double height;
}
