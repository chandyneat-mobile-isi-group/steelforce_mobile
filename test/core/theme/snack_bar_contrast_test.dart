import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';

/// Guards the defect that produced the phantom "white widget" on Home and the
/// Route Dashboard.
///
/// The light theme set `snackBarText` and `snackBarBackground` to the same
/// colour (`AppColors.textInverse`, pure white). The SnackBar still rendered
/// and still occupied layout — the text was simply invisible — so a long sync
/// failure message inflated the floating, rounded, elevated SnackBar into a
/// large blank white rectangle floating over the page.
///
/// A contrast assertion is the cheapest permanent guard: any future token edit
/// that collapses foreground into background fails here rather than shipping as
/// an unexplainable rendering bug.
void main() {
  /// WCAG relative luminance.
  double luminance(Color c) => c.computeLuminance();

  /// WCAG 2.1 contrast ratio between two opaque colours (1.0 … 21.0).
  double contrastRatio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  for (final (name, theme) in [
    ('light', AppTheme.light(AppTypography.latinFontFamily)),
    ('dark', AppTheme.dark(AppTypography.latinFontFamily)),
  ]) {
    group('$name theme SnackBar', () {
      late Color background;
      late Color foreground;

      setUp(() {
        final snack = theme.snackBarTheme;
        background = snack.backgroundColor!;
        foreground = snack.contentTextStyle!.color!;
      });

      test('text is not the same colour as its background', () {
        expect(
          foreground,
          isNot(background),
          reason: 'Identical fore/background renders the message invisible '
              'while it still occupies layout — the white-rectangle bug.',
        );
      });

      test('text meets the WCAG AA 4.5:1 contrast minimum', () {
        expect(
          contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: 'SnackBars carry error text; it must be legible.',
        );
      });
    });
  }
}
