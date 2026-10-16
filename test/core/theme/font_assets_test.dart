import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/theme/app_typography.dart';

/// Guards the font drop wired in `pubspec.yaml` and `AppTypography`.
///
/// Fonts fail *silently*: a missing file, a family renamed in pubspec but not in
/// `AppTypography`, or a web-only container (`.woff2`) all resolve to Flutter's
/// default font instead of throwing, so the only symptom is a screenshot that
/// looks subtly wrong — or, for Khmer, tofu boxes. These assertions turn each of
/// those into a test failure.

/// The declared `family:` → asset paths, parsed out of the pubspec `fonts:`
/// block. Line-scanned rather than parsed with `package:yaml`, which is only a
/// transitive dependency here.
Map<String, List<String>> _declaredFonts() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final fonts = <String, List<String>>{};
  var inFonts = false;
  String? family;

  for (final line in lines) {
    if (RegExp(r'^  fonts:\s*$').hasMatch(line)) {
      inFonts = true;
      continue;
    }
    if (!inFonts) continue;
    // Any other top-level (2-space) key ends the fonts block.
    if (RegExp(r'^  \S').hasMatch(line) && !line.trimLeft().startsWith('-')) {
      break;
    }

    final familyMatch = RegExp(r'^\s*-\s*family:\s*(.+?)\s*$').firstMatch(line);
    if (familyMatch != null) {
      family = familyMatch.group(1)!;
      fonts[family] = [];
      continue;
    }
    final assetMatch = RegExp(r'^\s*-\s*asset:\s*(.+?)\s*$').firstMatch(line);
    if (assetMatch != null && family != null) {
      fonts[family]!.add(assetMatch.group(1)!);
    }
  }
  return fonts;
}

/// `true` when [path] starts with an sfnt magic Flutter's font engine accepts.
/// Rejects `wOFF`/`wOF2`, web-only formats Flutter cannot load.
bool _isLoadableFont(String path) {
  final magic = File(path).readAsBytesSync().sublist(0, 4);
  const trueType = [0x00, 0x01, 0x00, 0x00];
  const openTypeCff = [0x4F, 0x54, 0x54, 0x4F]; // 'OTTO'
  const collection = [0x74, 0x74, 0x63, 0x66]; // 'ttcf'
  const trueMac = [0x74, 0x72, 0x75, 0x65]; // 'true'
  for (final accepted in [trueType, openTypeCff, collection, trueMac]) {
    if (magic[0] == accepted[0] &&
        magic[1] == accepted[1] &&
        magic[2] == accepted[2] &&
        magic[3] == accepted[3]) {
      return true;
    }
  }
  return false;
}

/// The `pdf` package parses the `glyf` table only — CFF-flavoured OpenType
/// ('OTTO') throws at export time, which no widget test would catch.
bool _hasGlyfOutlines(String path) {
  final magic = File(path).readAsBytesSync().sublist(0, 4);
  return magic[0] == 0x00 &&
      magic[1] == 0x01 &&
      magic[2] == 0x00 &&
      magic[3] == 0x00;
}

void main() {
  late Map<String, List<String>> declared;

  setUpAll(() => declared = _declaredFonts());

  test('pubspec declares exactly the two families AppTypography resolves to',
      () {
    expect(
      declared.keys.toSet(),
      {AppTypography.latinFontFamily, AppTypography.khmerFontFamily},
      reason: 'A family renamed in pubspec must be renamed in AppTypography '
          'too — Flutter falls back to the platform font instead of failing.',
    );
  });

  test('every declared font asset exists and is in a format Flutter can load',
      () {
    for (final entry in declared.entries) {
      expect(entry.value, isNotEmpty,
          reason: '${entry.key} declares no font assets');
      for (final path in entry.value) {
        expect(File(path).existsSync(), isTrue, reason: 'missing font: $path');
        expect(_isLoadableFont(path), isTrue,
            reason: '$path is not a ttf/otf/ttc — Flutter cannot load '
                'woff/woff2, it silently renders the default font instead');
      }
    }
  });

  test('both families cover the regular and bold weights the UI asks for', () {
    // AppTheme hand-writes w400/w600/w700 styles; Flutter snaps to the nearest
    // declared weight, but a family with a single weight would flatten the UI.
    for (final entry in declared.entries) {
      expect(entry.value.length, greaterThanOrEqualTo(3),
          reason: '${entry.key} should ship at least regular/medium/bold');
    }
  });

  test('locale resolution pairs each family with the other as fallback', () {
    const en = Locale('en');
    const km = Locale('km');

    expect(
        AppTypography.fontFamilyForLocale(en), AppTypography.latinFontFamily);
    expect(
        AppTypography.fontFamilyForLocale(km), AppTypography.khmerFontFamily);

    // The two families are script-disjoint: Source Sans 3 has no Khmer glyphs and
    // MiSans Khmer no Latin ones, so neither may resolve without the other.
    expect(AppTypography.fontFamilyFallbackForLocale(en),
        [AppTypography.khmerFontFamily]);
    expect(AppTypography.fontFamilyFallbackForLocale(km),
        [AppTypography.latinFontFamily]);
  });

  test('PDF export fonts exist and have glyf outlines', () {
    // Mirrors the paths loaded by PdfAssets.ensureLoaded().
    const pdfFonts = [
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Regular.ttf',
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Bold.ttf',
      'assets/fonts/khmer/MiSansKhmer-Regular.ttf',
      'assets/fonts/khmer/MiSansKhmer-Bold.ttf',
    ];
    for (final path in pdfFonts) {
      expect(File(path).existsSync(), isTrue,
          reason: 'PdfAssets loads $path — a rename here breaks every export');
      expect(_hasGlyfOutlines(path), isTrue,
          reason: '$path must be TrueType-outlined; pdf cannot parse CFF');
    }
  });
}
