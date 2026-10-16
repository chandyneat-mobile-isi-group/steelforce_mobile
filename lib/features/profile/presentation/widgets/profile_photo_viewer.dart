import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Hero tag shared by the header avatar and this viewer, so the picture grows
/// out of the circle instead of appearing from nowhere.
String profilePhotoHeroTag(String profileId) => 'profile-photo-$profileId';

/// Opens [url] full screen over a black backdrop.
///
/// Zoom by pinching, double-tapping, or the − / + buttons; swipe down (when
/// not zoomed) or tap ✕ to close. Only called when there is a picture: initials have nothing to
/// enlarge.
Future<void> showProfilePhotoViewer(
  BuildContext context, {
  required String url,
  required String heroTag,
  required String name,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) =>
        _ProfilePhotoViewer(url: url, heroTag: heroTag, name: name),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  ));
}

class _ProfilePhotoViewer extends StatefulWidget {
  const _ProfilePhotoViewer({
    required this.url,
    required this.heroTag,
    required this.name,
  });

  final String url;
  final String heroTag;
  final String name;

  @override
  State<_ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<_ProfilePhotoViewer>
    with SingleTickerProviderStateMixin {
  static const _minScale = 1.0;
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.5;

  /// Each tap on + or − multiplies or divides the zoom by this.
  static const _buttonStep = 1.5;

  /// How far a downward swipe must travel before letting go closes the viewer.
  static const _dismissDistance = 120.0;

  final _zoom = TransformationController();
  late final AnimationController _zoomAnimation;
  Matrix4Tween? _zoomTween;
  Offset? _doubleTapAt;
  Size _viewport = Size.zero;

  double _dragY = 0;
  bool _dragging = false;
  bool _chromeVisible = true;

  double get _scale => _zoom.value.getMaxScaleOnAxis();
  bool get _zoomed => _scale > _minScale + 0.01;

  @override
  void initState() {
    super.initState();
    // Created here, not lazily: a lazy controller first built inside
    // dispose() looks up TickerMode on a deactivated element and throws.
    _zoomAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => _zoom.value = _zoomTween!.evaluate(_zoomAnimation));
  }

  @override
  void dispose() {
    _zoomAnimation.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// Animates to [target] scale, keeping the photo point under [focal] still
  /// and never letting an edge of the photo come away from the screen edge.
  void _zoomTo(double target, Offset focal) {
    target = target.clamp(_minScale, _maxScale);
    final current = _zoom.value;
    final k = target / _scale;
    final next = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(current);
    // The photo is exactly viewport-sized, so at scale s the translation
    // must stay within [viewport * (1 - s), 0] on each axis.
    next.storage[12] =
        next.storage[12].clamp(_viewport.width * (1 - target), 0.0);
    next.storage[13] =
        next.storage[13].clamp(_viewport.height * (1 - target), 0.0);

    _zoomTween = Matrix4Tween(begin: current, end: next);
    _zoomAnimation.forward(from: 0);
  }

  Offset get _centre => _viewport.center(Offset.zero);

  void _onDoubleTap() {
    // Zoomed: back to fit. Not zoomed: in around the tapped point, so the face
    // the rep tapped stays under their finger.
    _zoomTo(_zoomed ? _minScale : _doubleTapScale, _doubleTapAt ?? _centre);
  }

  // Swipe-to-close rides on InteractiveViewer's own gesture, not a second
  // drag recogniser: a parent vertical-drag detector competes with the
  // two-finger pinch and could win it, which is what made pinch unreliable.
  void _onInteractionUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount != 1 || _zoomed) return;
    if (!_dragging && d.focalPointDelta.dy <= 0) return;
    setState(() {
      _dragging = true;
      _dragY = (_dragY + d.focalPointDelta.dy).clamp(0.0, 1000.0);
    });
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (!_dragging) {
      setState(() {}); // refresh the zoom label
      return;
    }
    final fling = d.velocity.pixelsPerSecond.dy > 700;
    if (_dragY > _dismissDistance || fling) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _dragging = false;
      _dragY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Light on black whatever the app theme: this is a photo viewer.
    const foreground = Colors.white;
    // The backdrop thins as the photo is dragged down, showing the drag
    // will close it.
    final backdrop = (1 - (_dragY / 400)).clamp(0.4, 1.0);
    final chromeShown = _chromeVisible && _dragY == 0;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: backdrop),
      // `expand`: a loose Stack sizes itself to its non-positioned children —
      // here, the top bar — which squeezed the photo into a 64px strip.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: LayoutBuilder(builder: (context, box) {
              _viewport = box.biggest;
              return GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                onDoubleTap: _onDoubleTap,
                child: AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(0, _dragY, 0),
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    minScale: _minScale,
                    maxScale: _maxScale,
                    onInteractionUpdate: _onInteractionUpdate,
                    onInteractionEnd: _onInteractionEnd,
                    // Sized to the whole screen so `BoxFit.contain` fills the
                    // width and centres the photo, whatever its pixel size.
                    child: Hero(
                      tag: widget.heroTag,
                      child: _Photo(
                        url: widget.url,
                        name: widget.name,
                        width: box.maxWidth,
                        height: box.maxHeight,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Chrome(
              visible: chromeShown,
              top: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    context.rw(4), 0, context.rw(16), context.rh(16)),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded, color: foreground),
                      iconSize: context.rr(26),
                    ),
                    SizedBox(width: context.rw(4)),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: context.rsp(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Chrome(
              visible: chromeShown,
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                    top: context.rh(24), bottom: context.rh(12)),
                child: Center(
                  child: ValueListenableBuilder<Matrix4>(
                    valueListenable: _zoom,
                    builder: (context, _, __) => _ZoomControls(
                      scale: _scale,
                      onZoomOut: _scale > _minScale + 0.01
                          ? () => _zoomTo(_scale / _buttonStep, _centre)
                          : null,
                      onZoomIn: _scale < _maxScale - 0.01
                          ? () => _zoomTo(_scale * _buttonStep, _centre)
                          : null,
                      onReset:
                          _zoomed ? () => _zoomTo(_minScale, _centre) : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar that fades with the tap-to-hide toggle, over a gradient that keeps
/// white controls readable on a light photo.
class _Chrome extends StatelessWidget {
  const _Chrome(
      {required this.visible, required this.top, required this.child});

  final bool visible;

  /// Top bar: dark at the top edge. Bottom bar: dark at the bottom edge.
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(
        ignoring: !visible,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0),
              ],
            ),
          ),
          child: SafeArea(top: top, bottom: !top, child: child),
        ),
      ),
    );
  }
}

/// − · 100% · + — the visible way to zoom, for a rep who does not know to
/// pinch. Tapping the percentage fits the photo again.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.scale,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
  });

  final double scale;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    const foreground = Colors.white;
    final disabled = foreground.withValues(alpha: 0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onZoomOut,
            tooltip: 'profile.zoom_out'.tr,
            icon: const Icon(Icons.remove_rounded),
            color: foreground,
            disabledColor: disabled,
            iconSize: context.rr(24),
          ),
          Semantics(
            button: onReset != null,
            label: 'profile.zoom_reset'.tr,
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
                child: Center(
                  child: Text(
                    '${(scale * 100).round()}%',
                    style: TextStyle(
                      color: foreground,
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onZoomIn,
            tooltip: 'profile.zoom_in'.tr,
            icon: const Icon(Icons.add_rounded),
            color: foreground,
            disabledColor: disabled,
            iconSize: context.rr(24),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.url,
    required this.name,
    required this.width,
    required this.height,
  });

  final String url;
  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    const foreground = Colors.white;

    return Image(
      image: CachedNetworkImageProvider(url),
      width: width,
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'profile.avatar_label'.trParams({'name': name}),
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Stack(
              alignment: Alignment.center,
              children: [
                child,
                const CircularProgressIndicator(color: foreground),
              ],
            ),
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined,
                color: foreground.withValues(alpha: 0.7), size: context.rr(48)),
            SizedBox(height: context.rh(12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.rw(32)),
              child: Text(
                'profile.photo_unavailable'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.8),
                  fontSize: context.rsp(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
