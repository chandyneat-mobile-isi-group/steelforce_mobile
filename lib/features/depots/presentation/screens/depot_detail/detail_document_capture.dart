part of '../depot_detail_screen.dart';

/// The tallest image saved, in pixels; a depot with many contacts or sales
/// areas is drawn at a lower pixel ratio rather than run out of memory.
const double _maxDocumentPixels = 12000;

/// Lays [depot]'s document out off screen, draws it, and saves it to the
/// photos as one image. True when it was saved.
///
/// Always in the light theme: a document is read on white, whatever the
/// phone's setting. Laid out in an overlay entry past the screen's left
/// edge, so it is painted (which drawing needs) but never seen.
Future<bool> _saveDepotDocument(BuildContext context, Depot depot) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  final width = MediaQuery.sizeOf(context).width.clamp(360.0, 600.0);
  final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily ??
      AppTypography.latinFontFamily;
  final watermark = await _loadWatermark();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -width * 2,
      top: 0,
      width: width,
      child: IgnorePointer(
        child: RepaintBoundary(
          key: key,
          child: Theme(
            data: AppTheme.light(fontFamily),
            child: _DepotDocument(
              depot: depot,
              printedAt: DateTime.now(),
              watermark: watermark,
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;
    final ratio = (_maxDocumentPixels / boundary.size.height).clamp(1.0, 3.0);
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return false;
    await Gal.putImageBytes(bytes.buffer.asUint8List());
    return true;
  } catch (_) {
    // The caller says it failed; a raw exception never reaches the screen.
    return false;
  } finally {
    entry.remove();
    watermark?.picture.dispose();
  }
}
