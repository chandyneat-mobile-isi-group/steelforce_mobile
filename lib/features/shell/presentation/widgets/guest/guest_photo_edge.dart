import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_chevron_painter.dart';

/// Where the photo meets the navy panel: the brand chevron, an Apex Blue band
/// over Ironclad navy, with valleys at both edges and the centre.
///
/// Sits on the bottom of the photo; its own height is [heightFor].
class GuestPhotoEdge extends StatelessWidget {
  const GuestPhotoEdge({super.key});

  /// Two periods across a phone, as in the artwork; three on wider windows,
  /// so the peaks stay low rather than towering over the photo.
  static double periodFor(double width) =>
      width < 600 ? width / 2 : (width / 3).clamp(220.0, 360.0);

  static const _band = 10.0;

  static double heightFor(double width) =>
      periodFor(width) * GuestChevronPainter.riseRatio + _band;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: heightFor(width),
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: GuestChevronPainter(
            period: periodFor(width),
            bandThickness: _band,
            fillToBottom: true,
            layers: const [AppColors.primary, AppColors.brandNavy],
          ),
        ),
      ),
    );
  }
}
