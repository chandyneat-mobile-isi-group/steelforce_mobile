import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/inventory_photo_tiles.dart';

/// The photos chosen so far: a "Photos (n/max)" header, progress towards
/// the minimum, and a strip of thumbnails ending in an "Add more" tile.
class InventoryPhotosCard extends StatelessWidget {
  const InventoryPhotosCard({
    super.key,
    required this.photos,
    required this.minPhotos,
    required this.maxPhotos,
    required this.onRemove,
    required this.onAdd,
  });

  /// Each photo's preview, with the picked file as its identity: two
  /// photos can share bytes, never a file.
  final List<({Object id, Uint8List bytes})> photos;
  final int minPhotos;
  final int maxPhotos;

  /// Null while saving, which hides the remove badges.
  final ValueChanged<int>? onRemove;

  /// Null while saving, full, or with no camera; hides the add tile.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final count = photos.length;
    final ready = count >= minPhotos;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tile = context.rr(92);

    return Container(
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.rr(8)),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(context.rr(10)),
                ),
                child: Icon(Icons.photo_library_outlined,
                    color: scheme.primary, size: context.rr(20)),
              ),
              SizedBox(width: context.rw(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: AppDurations.medium,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        alignment: Alignment.centerLeft,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        'my_visits.survey.photos_title'
                            .trParams({'count': count, 'max': maxPhotos}),
                        key: ValueKey(count),
                        style: TextStyle(
                            fontSize: context.rsp(16),
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary),
                      ),
                    ),
                    Text(
                      'my_visits.survey.photos_rule'
                          .trParams({'min': minPhotos, 'max': maxPhotos}),
                      style: TextStyle(
                          fontSize: context.rsp(12),
                          color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: ready ? 1 : 0,
                duration: AppDurations.medium,
                child: Icon(Icons.check_circle_rounded,
                    color: colors.success, size: context.rr(24)),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (count / minPhotos).clamp(0.0, 1.0)),
            duration: reduceMotion ? Duration.zero : AppDurations.entrance,
            curve: AppCurves.emphasized,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(context.rr(4)),
              child: LinearProgressIndicator(
                value: value,
                minHeight: context.rh(6),
                backgroundColor: colors.border,
                color: ready ? colors.success : scheme.primary,
              ),
            ),
          ),
          SizedBox(height: context.rh(14)),
          if (count == 0)
            InventoryAddPhotoTile(
              size: tile,
              wide: true,
              maxPhotos: maxPhotos,
              onTap: onAdd,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final (i, photo) in photos.indexed) ...[
                    InventoryPhotoThumb(
                      // Keyed by the photo, so removing one does not replay
                      // the entrance of the photos after it.
                      key: ObjectKey(photo.id),
                      bytes: photo.bytes,
                      index: i,
                      maxPhotos: maxPhotos,
                      size: tile,
                      onRemove: onRemove == null ? null : () => onRemove!(i),
                    ),
                    SizedBox(width: context.rw(10)),
                  ],
                  if (onAdd != null && count < maxPhotos)
                    InventoryAddPhotoTile(
                      size: tile,
                      wide: false,
                      maxPhotos: maxPhotos,
                      onTap: onAdd,
                    ),
                ],
              ),
            ),
          AnimatedSize(
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            child: count > 0 && count < maxPhotos && onAdd != null
                ? Padding(
                    padding: EdgeInsets.only(top: context.rh(12)),
                    child: _StillAddHint(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StillAddHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(12), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(12)),
      ),
      child: Row(
        children: [
          Icon(Icons.photo_camera_outlined,
              color: scheme.primary, size: context.rr(22)),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text('my_visits.survey.still_add'.tr,
                style: TextStyle(
                    fontSize: context.rsp(12),
                    height: 1.4,
                    color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
