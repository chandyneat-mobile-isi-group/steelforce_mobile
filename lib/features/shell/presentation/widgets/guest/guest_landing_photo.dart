import 'package:flutter/material.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// The guest landing photograph — the ISI tube mill — filling whatever room
/// the panel below leaves it.
///
/// The top is darkened a little so the status bar's white icons stay legible
/// over the bright factory roof.
class GuestLandingPhoto extends StatelessWidget {
  const GuestLandingPhoto({super.key, this.alignment = Alignment.center});

  static const asset = AppImages.guestFactoryHero;

  /// Which part of the photo stays in frame when it is cropped.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: alignment,
          // Decorative: the headline says what the app is for.
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x66000000), Color(0x00000000)],
            ),
          ),
        ),
      ],
    );
  }
}
