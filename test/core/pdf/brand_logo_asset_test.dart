import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

/// Guards the two ISI Group wordmark SVGs that `BrandLogo` and the quotation
/// PDF header draw.
///
/// Both failure modes here are silent. A malformed or unsupported SVG renders
/// as *nothing* — an export with a blank header still saves fine and still
/// reaches the depot — and swapping the two ink variants produces a mark
/// the same colour as the surface behind it, which is equally invisible and
/// equally undetectable from a green test run.
///
/// The filenames name the ink, and each file's `<title>` names the surface it
/// belongs on. This suite trusts neither: it reads the actual fill, because a
/// swap here is invisible in review and invisible on screen.
void main() {
  /// Navy `#011E41` — drawn on light surfaces and on PDF paper.
  const darkInkPath = 'assets/logos/isi-steel-dark.svg';

  /// Near-white `#DCE3EB` — drawn on dark surfaces.
  const lightInkPath = 'assets/logos/isi-steel-light.svg';

  test('both ink variants exist and are declared under a bundled directory',
      () {
    expect(File(darkInkPath).existsSync(), isTrue,
        reason: '$darkInkPath is missing');
    expect(File(lightInkPath).existsSync(), isTrue,
        reason: '$lightInkPath is missing');
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/logos/'),
      reason: 'assets/logos/ must stay in the pubspec assets list',
    );
  });

  test('the ink variants are not swapped', () {
    // If these two ever trade places, every surface in the app shows the mark
    // in the colour of the surface behind it. This assertion has already caught
    // that once, from a misread of which file carried which fill.
    expect(File(darkInkPath).readAsStringSync(), contains('#011E41'),
        reason: '$darkInkPath must carry the navy ink for light surfaces');
    expect(File(lightInkPath).readAsStringSync(), contains('#DCE3EB'),
        reason:
            '$lightInkPath must carry the near-white ink for dark surfaces');
  });

  test('BrandLogo and the PDF header point at the ink these tests assert', () {
    // The guard above only means something if production reads the same two
    // files. Asserted against source so a rename in one place cannot quietly
    // leave this suite testing assets nobody draws.
    final brandLogo =
        File('lib/shared/widgets/brand_logo.dart').readAsStringSync();
    expect(brandLogo, contains("_darkInkAsset = '$darkInkPath'"));
    expect(brandLogo, contains("_lightInkAsset = '$lightInkPath'"));

    expect(
      File('lib/core/pdf/document/pdf_assets.dart').readAsStringSync(),
      contains("loadString('$darkInkPath')"),
      reason: 'a PDF is drawn on white paper and needs the navy mark',
    );
  });

  test('the PDF header variant renders through the PDF SVG engine', () async {
    // `PdfAssets` loads this exact file for the quotation header and
    // `quotation_pdf_generator` draws it with `pw.SvgImage`. The pdf package
    // implements a *subset* of SVG, so "flutter_svg can draw it" is not
    // evidence the export can — and this artwork was re-exported, so the
    // subset question is live again rather than settled.
    final svg = File(darkInkPath).readAsStringSync();

    Future<int> lengthOf(pw.Widget child) async {
      final doc = pw.Document();
      doc.addPage(pw.Page(build: (_) => child));
      return (await doc.save()).length;
    }

    final empty = await lengthOf(pw.SizedBox());
    final drawn = await lengthOf(pw.SvgImage(svg: svg, height: 34));

    // Measured against an empty page rather than asserting `isNotEmpty`: a
    // document whose SVG silently drew nothing still saves, and still carries
    // ~500 bytes of PDF scaffolding. Only the delta says the six paths in the
    // wordmark actually reached the content stream.
    expect(drawn, greaterThan(empty + 500),
        reason: 'the wordmark emitted no geometry into the PDF');
  });
}
