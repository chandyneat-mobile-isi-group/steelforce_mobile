import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';

/// The Work Mode confirm dialog's header: the vivid brand wallpaper, a close
/// button, and the target mode's icon in a white disc.
class WorkModeDialogHeader extends StatelessWidget {
  const WorkModeDialogHeader({
    super.key,
    required this.toOffline,
    required this.boxScale,
  });

  /// The mode being switched to; picks the icon.
  final bool toOffline;

  /// The dialog's width-class box scale (1.0 on phones).
  final double boxScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.appColors;
    return SizedBox(
      height: 116 * boxScale,
      child: Stack(
        children: [
          const Positioned.fill(
            child: BrandWallpaperBackground(),
          ),
          Positioned(
            top: 8 * boxScale,
            right: 8 * boxScale,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 64 * boxScale,
              height: 64 * boxScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? c.card : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                toOffline ? Icons.phone_android_rounded : Icons.wifi_rounded,
                size: 30 * boxScale,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
