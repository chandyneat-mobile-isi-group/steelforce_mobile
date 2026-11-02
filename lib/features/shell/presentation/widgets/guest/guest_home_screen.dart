import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_landing_photo.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_panel_content.dart';
import 'package:steelforce/features/shell/presentation/widgets/guest/guest_photo_edge.dart';

/// The guest (signed-out) home: the ISI tube mill above, a navy panel below
/// with the brand, the pitch, the work areas and one way in.
///
/// The same in light and dark themes — photo and Ironclad navy read in both.
///
/// - **Portrait** (phones, tablets): photo on top, cut by the brand chevron;
///   the panel takes what its content needs and the photo the rest. Fits one
///   phone screen; with large text it scrolls rather than clipping.
/// - **Landscape** (wide tablets, desktop): photo on the left, the panel on
///   the right behind an Apex Blue rule.
class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key, required this.onLogin});

  /// Opens the shared login prompt.
  final VoidCallback onLogin;

  /// Panel content never runs wider than a comfortable reading measure.
  static const _maxContentWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height && size.width >= 800;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the photo's darkened top.
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.brandNavy,
        child:
            isLandscape ? _landscape(context, size) : _portrait(context, size),
      ),
    );
  }

  Widget _portrait(BuildContext context, Size size) {
    final insets = MediaQuery.viewPaddingOf(context);
    // The photo never shrinks below the status bar, the chevron and a strip
    // of factory — past that the page scrolls instead.
    final minPhoto =
        insets.top + GuestPhotoEdge.heightFor(size.width) + context.rh(120);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SizedBox(
                  height: minPhoto,
                  child: const Stack(
                    fit: StackFit.expand,
                    children: [
                      // Stops short of the bottom, so no sliver of photo
                      // can show under the chevron's anti-aliased edge.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 2,
                        child: GuestLandingPhoto(
                          alignment: Alignment(0.2, -0.2),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: GuestPhotoEdge(),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: GuestPanelContent(onLogin: onLogin),
                ),
              ),
              SizedBox(height: insets.bottom),
            ],
          ),
        ),
      ],
    );
  }

  Widget _landscape(BuildContext context, Size size) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(child: GuestLandingPhoto()),
        Container(
          width: (size.width * 0.44).clamp(380.0, _maxContentWidth),
          decoration: const BoxDecoration(
            color: AppColors.brandNavy,
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 8),
            ),
          ),
          child: SafeArea(
            left: false,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: GuestPanelContent(
                      onLogin: onLogin,
                      headlineSize: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
