import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/shared/widgets/settings_section_card.dart';

/// The Appearance and Language blocks sit directly on top of each other on the
/// Profile screen, and they used to be two hand-maintained copies of the same
/// layout — one sized with the responsive helpers, the other with its own
/// `isTablet ? 18 : 14.5` ladder. They rendered at visibly different type and
/// padding, and *inverted* above 600pt where the helpers scale past the
/// hardcoded tablet values.
///
/// These tests pin the contract that replaced that: one shared widget, so two
/// sections are identical by construction, and type that grows with the window
/// rather than against it.
void main() {
  // Mirrors `app.dart`: compact keeps the 390x844 phone design, larger windows
  // use the real viewport so the scale factor is 1.0 and the responsive
  // helpers, not ScreenUtil, do the growing.
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: Breakpoints.fromWidth(size.width).isCompact
            ? const Size(390, 844)
            : size,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Scaffold(
            body: ListView(
              children: [
                SettingsSectionCard(
                  title: 'Appearance',
                  children: [
                    SettingsRow(
                      icon: Icons.light_mode_rounded,
                      label: 'Theme',
                      value: 'Light',
                      onTap: () {},
                    ),
                  ],
                ),
                SettingsSectionCard(
                  title: 'Language',
                  children: [
                    SettingsRow(
                      icon: Icons.translate_rounded,
                      // Deliberately the same length as the row above: this
                      // pair of tests is about the *widget* being identical,
                      // and a longer label legitimately wraps to a second line.
                      // Wrapping is covered on its own below.
                      label: 'Locale',
                      value: 'English',
                      valuePrefix: const Text('KH'),
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double fontSizeOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.fontSize!;

  /// Height of the row's tap target — the metric that makes two stacked cards
  /// look aligned or not.
  double rowHeightOf(WidgetTester tester, String label) => tester
      .getSize(find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first)
      .height;

  const phone = Size(390, 844);
  const tablet = Size(834, 1112); // iPad Air portrait — `medium`

  testWidgets('both sections render at identical type and row height',
      (tester) async {
    await pumpAt(tester, phone);

    expect(fontSizeOf(tester, 'Appearance'), fontSizeOf(tester, 'Language'),
        reason: 'section titles must match');
    expect(fontSizeOf(tester, 'Theme'), fontSizeOf(tester, 'Locale'),
        reason: 'row labels must match');
    expect(fontSizeOf(tester, 'Light'), fontSizeOf(tester, 'English'),
        reason: 'row values must match');
    expect(rowHeightOf(tester, 'Theme'), rowHeightOf(tester, 'Locale'),
        reason: 'rows must be the same height, or the cards read as unaligned');
  });

  testWidgets('the two sections stay identical on a tablet', (tester) async {
    await pumpAt(tester, tablet);

    expect(fontSizeOf(tester, 'Appearance'), fontSizeOf(tester, 'Language'));
    expect(fontSizeOf(tester, 'Theme'), fontSizeOf(tester, 'Locale'));
    expect(rowHeightOf(tester, 'Theme'), rowHeightOf(tester, 'Locale'));
  });

  testWidgets('type and rows grow on a tablet rather than shrinking',
      (tester) async {
    await pumpAt(tester, phone);
    final phoneTitle = fontSizeOf(tester, 'Appearance');
    final phoneLabel = fontSizeOf(tester, 'Theme');
    final phoneRow = rowHeightOf(tester, 'Theme');

    await pumpAt(tester, tablet);

    // The `medium` type scale is 1.50 and the box scale 1.30 — see
    // ResponsiveSizing. The exact ratio is that class's business; what matters
    // here is that the tablet is unambiguously bigger, which is what the old
    // hardcoded `isTablet ? 16` values got wrong.
    expect(fontSizeOf(tester, 'Appearance'), greaterThan(phoneTitle));
    expect(fontSizeOf(tester, 'Theme'), greaterThan(phoneLabel));
    expect(rowHeightOf(tester, 'Theme'), greaterThan(phoneRow));
  });

  testWidgets('a long value ellipsizes instead of overflowing the row',
      (tester) async {
    // Khmer values run longer than their English equivalents; the row must
    // absorb that without a yellow-and-black overflow stripe.
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Scaffold(
            body: SettingsSectionCard(
              title: 'Language',
              children: [
                SettingsRow(
                  icon: Icons.translate_rounded,
                  label: 'Display language',
                  value: 'ភាសាខ្មែរ ភាសាខ្មែរ ភាសាខ្មែរ ភាសាខ្មែរ',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
