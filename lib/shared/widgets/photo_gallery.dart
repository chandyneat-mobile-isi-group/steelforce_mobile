import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One photo to show: a local file the app saved, or a URL.
class GalleryPhoto {
  const GalleryPhoto({required this.path, required this.label, this.takenAt});

  final String path;

  /// What the photo is ("Storefront", "Signature") — shown under the
  /// thumbnail and in the viewer.
  final String label;
  final DateTime? takenAt;

  bool get isRemote => path.contains('://');
}

/// A row of photo thumbnails; a tap opens them full screen.
///
/// For work saved on the device and not yet sent — depot document photos,
/// visit photos — so the rep can check what will go before it goes. A file
/// that has gone missing shows as such rather than as an error.
class PhotoGallery extends StatelessWidget {
  const PhotoGallery({super.key, required this.photos});

  final List<GalleryPhoto> photos;

  static const double _thumb = 96;

  @override
  Widget build(BuildContext context) {
    final size = context.rr(_thumb);
    return SizedBox(
      // Thumbnail, gap, one line of label at the device's text scale.
      height: size + context.rh(8) + context.rsp(14) * 1.4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => SizedBox(width: context.rw(10)),
        itemBuilder: (context, i) => _Thumbnail(
          photo: photos[i],
          size: size,
          onTap: () => showPhotoViewer(context, photos, initialIndex: i),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.photo,
    required this.size,
    required this.onTap,
  });

  final GalleryPhoto photo;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      button: true,
      label: photo.label,
      excludeSemantics: true,
      // The whole tile — photo and its label — opens the viewer.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: size,
                height: size,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surfaceStrong,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: _PhotoImage(
                  photo: photo,
                  fit: BoxFit.cover,
                  cacheWidth: (size * dpr).round(),
                ),
              ),
              SizedBox(height: context.rh(8)),
              Text(
                photo.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The image itself, or a calm "not available" when the file is gone (or on
/// web, where a device path never exists).
class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.photo, this.fit, this.cacheWidth});

  final GalleryPhoto photo;
  final BoxFit? fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (photo.isRemote) {
      return Image.network(
        photo.path,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (context, _, __) => const _Unavailable(),
      );
    }
    if (!localFileExists(photo.path)) return const _Unavailable();
    return localFileImage(photo.path, fit: fit, cacheWidth: cacheWidth);
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: colors.iconMuted, size: context.rr(24)),
          SizedBox(height: context.rh(4)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.rw(6)),
            child: Text(
              'photo_gallery.unavailable'.tr,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textHint,
                fontSize: context.rsp(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen, swipe between [photos], pinch to zoom.
Future<void> showPhotoViewer(
  BuildContext context,
  List<GalleryPhoto> photos, {
  int initialIndex = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PhotoViewer(photos: photos, initialIndex: initialIndex),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<GalleryPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    final takenAt = photo.takenAt;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'photo_gallery.close'.tr,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              photo.label,
              style: TextStyle(
                fontSize: context.rsp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              [
                'photo_gallery.position'.trParams({
                  'index': _index + 1,
                  'total': widget.photos.length,
                }),
                if (takenAt != null)
                  DateFormat.yMMMd(context.languageCode)
                      .add_jm()
                      .format(takenAt.toLocal()),
              ].join(' · '),
              style: TextStyle(
                fontSize: context.rsp(11.5),
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => _ZoomablePhoto(photo: widget.photos[i]),
      ),
    );
  }
}

/// Pinch to zoom one photo. Panning is enabled only while zoomed in:
/// otherwise the viewer would claim every horizontal drag and the rep could
/// never swipe to the next photo.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.photo});

  final GalleryPhoto photo;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transform,
      maxScale: 5,
      panEnabled: _zoomed,
      onInteractionEnd: _onInteractionEnd,
      child: Center(
        child: _PhotoImage(photo: widget.photo, fit: BoxFit.contain),
      ),
    );
  }
}
