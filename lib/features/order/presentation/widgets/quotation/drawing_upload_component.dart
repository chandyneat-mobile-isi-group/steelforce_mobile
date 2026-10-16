import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';

class DrawingUploadComponent extends StatelessWidget {
  final String? imagePath;
  final Function(ImageCaptureSource source) onPickImage;
  final VoidCallback onRemoveImage;

  const DrawingUploadComponent({
    super.key,
    required this.imagePath,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (imagePath != null && localFileExists(imagePath!)) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surfaceContainerLow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Stack(
              children: [
                localFileImage(
                  (imagePath!),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    child: IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: onRemoveImage,
                      tooltip: 'Remove Drawing',
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colorScheme.surface,
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: colorScheme.primary, size: context.rr(20)),
                  SizedBox(width: context.rw(8)),
                  Text(
                    'Custom Drawing Attached',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showSourcePicker(context),
                    icon: Icon(Icons.refresh_rounded, size: context.rr(18)),
                    label: const Text('Replace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.rr(20)),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.draw_rounded,
              size: context.rr(48), color: colorScheme.primary),
          SizedBox(height: context.rh(12)),
          Text(
            'Attach Product Drawing or Sketch',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.rh(4)),
          Text(
            'Capture site measurements or technical sketches',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.rh(16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => onPickImage(ImageCaptureSource.camera),
                icon: Icon(Icons.camera_alt_rounded, size: context.rr(18)),
                label: const Text('Camera'),
              ),
              SizedBox(width: context.rw(12)),
              OutlinedButton.icon(
                onPressed: () => onPickImage(ImageCaptureSource.gallery),
                icon: Icon(Icons.photo_library_rounded, size: context.rr(18)),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet(
      constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo via Camera'),
              onTap: () {
                Navigator.pop(ctx);
                onPickImage(ImageCaptureSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                onPickImage(ImageCaptureSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
