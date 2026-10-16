import 'package:pdf/pdf.dart';

/// Enterprise design tokens shared by **every** ISI PDF document (quotation,
/// invoice, visit report, …).
///
/// Kept deliberately separate from the Flutter [ThemeData]/`AppThemeColors`:
/// a PDF is a print artifact, not a screen, and must render identically
/// regardless of the app's light/dark mode. Swapping brand colors here
/// restyles every generated document at once, so feature generators never
/// hardcode a color.
class PdfTheme {
  const PdfTheme();

  // ── Brand ────────────────────────────────────────────────────────────
  PdfColor get brandNavy => const PdfColor.fromInt(0xFF0A2A4A);
  PdfColor get brandAccent => const PdfColor.fromInt(0xFF1E6FBA);
  PdfColor get brandGreenDark =>
      const PdfColor.fromInt(0xFF143E2B); // Enterprise dark forest green
  PdfColor get brandGreen => const PdfColor.fromInt(
      0xFF2C9942); // ISI Sustainable Green (Pantone 7739 C)
  PdfColor get brandGreenLight =>
      const PdfColor.fromInt(0xFFEDF7EE); // Subtle green highlight tint
  PdfColor get borderLight =>
      const PdfColor.fromInt(0xFFE5E7EB); // Clean precision hairline

  // ── Text ─────────────────────────────────────────────────────────────
  PdfColor get ink => const PdfColor.fromInt(0xFF1A1F26);
  PdfColor get muted => const PdfColor.fromInt(0xFF6B7280);
  PdfColor get onBrand => const PdfColor.fromInt(0xFFFFFFFF);

  // ── Surfaces / lines ─────────────────────────────────────────────────
  PdfColor get hairline => const PdfColor.fromInt(0xFFD8DEE6);
  PdfColor get zebra => const PdfColor.fromInt(0xFFF3F6FA);
  PdfColor get panel => const PdfColor.fromInt(0xFFF7F9FC);

  // ── Semantic ─────────────────────────────────────────────────────────
  PdfColor get success => const PdfColor.fromInt(0xFF1B7F4B);
  PdfColor get danger => const PdfColor.fromInt(0xFFB42318);

  // ── Spacing scale (points) ───────────────────────────────────────────
  double get gapXs => 4;
  double get gapSm => 8;
  double get gapMd => 14;
  double get gapLg => 20;
  double get gapXl => 28;
}
