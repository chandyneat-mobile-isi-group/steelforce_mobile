import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The employee's picture in a circle, or their initials when there is none.
///
/// [previewBytes] wins over [url]: it is a picture just picked in the edit
/// sheet and not yet saved. With neither, initials — never a stock photo,
/// which reads as somebody else's face on your account.
///
/// Network avatars are cached freely: the server marks them immutable, and a
/// replaced picture gets a new address rather than new bytes at the old one.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.size,
    this.url,
    this.previewBytes,
    this.semanticLabel,
  });

  final String initials;
  final double size;
  final String? url;
  final Uint8List? previewBytes;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final fallback = ColoredBox(
      color: scheme.primary.withValues(alpha: 0.10),
      child: Center(
        child: Text(
          initials,
          // The circle has a fixed size, so the initials scale with it
          // rather than with the text scale factor — at 200% they would
          // otherwise spill out of the circle.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: scheme.primary,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    final Widget image;
    if (previewBytes case final bytes?) {
      image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url case final address?) {
      image = CachedNetworkImage(
        imageUrl: address,
        fit: BoxFit.cover,
        memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      );
    } else {
      image = fallback;
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceStrong,
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: ClipOval(child: ExcludeSemantics(child: image)),
      ),
    );
  }
}
