part of '../depot_detail_screen.dart';

/// The navy mark: the document is always drawn on the light theme.
const String _watermarkAsset = AppLogos.isiSteel;

/// Loads the ISI Steel logo for the watermark before the document is drawn.
/// An `SvgPicture` would load it a frame late — after the capture. Null when
/// it cannot be loaded: the document is still worth saving without it.
Future<PictureInfo?> _loadWatermark() async {
  try {
    return await vg.loadPicture(const SvgAssetLoader(_watermarkAsset), null);
  } catch (_) {
    return null;
  }
}

/// `logo | logo | …` down the middle of the document, top to bottom, at 20%
/// opacity — over the cards so a card's white cannot hide it.
class _WatermarkPainter extends CustomPainter {
  const _WatermarkPainter(this.logo);

  final PictureInfo logo;

  static const double _opacity = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final logoSize = logo.size;
    if (logoSize.isEmpty) return;

    // Each logo 60% of the width, centred across it; a short dash between
    // logos, a logo-height of space either side of it.
    final logoWidth = size.width * 0.6;
    final scale = logoWidth / logoSize.width;
    final logoHeight = logoSize.height * scale;
    final gap = logoHeight;
    final dashLength = logoHeight * 0.6;
    final step = logoHeight + 2 * gap + dashLength;
    // As many as fit, the column centred down the height.
    final count = ((size.height + 2 * gap + dashLength) / step).floor();
    if (count < 1) return;
    final columnHeight = count * step - 2 * gap - dashLength;
    final left = (size.width - logoWidth) / 2;
    final centreX = size.width / 2;
    var y = (size.height - columnHeight) / 2;

    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, _opacity),
    );
    final dash = Paint()
      ..color = const Color(0xFF011E41)
      ..strokeWidth = logoHeight * 0.06
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      canvas
        ..save()
        ..translate(left, y)
        ..scale(scale)
        ..drawPicture(logo.picture)
        ..restore();
      y += logoHeight;
      if (i < count - 1) {
        canvas.drawLine(Offset(centreX, y + gap),
            Offset(centreX, y + gap + dashLength), dash);
        y += 2 * gap + dashLength;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) => oldDelegate.logo != logo;
}
