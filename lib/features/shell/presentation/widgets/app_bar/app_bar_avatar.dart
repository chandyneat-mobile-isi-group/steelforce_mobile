/// The signed-in user's avatar in the shell app bar: a brand-blue frame
/// around picture → initials → person icon. Restyle the frame or fallback here.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// User Avatar — a 3D brand-blue frame.
class AppBarAvatar extends StatelessWidget {
  const AppBarAvatar({
    super.key,
    required this.onTap,
    required this.isHome,
    this.url,
    this.initials,
  });

  final VoidCallback onTap;
  final bool isHome;
  final String? url;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Icon-only control: the label gives a screen reader something to say.
    return Semantics(
      button: true,
      label: 'profile.title'.tr,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: context.rr(38),
          height: context.rr(38),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rr(12)),
            // Brand-blue outer rim
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.secondary,
                AppColors.primary,
                AppColors.brandNavy
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isHome ? 0.35 : 0.15),
                offset: const Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          padding: EdgeInsets.all(context.rr(1.5)), // Rim width
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(context.rr(10.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _AvatarImage(url: url, initials: initials),
          ),
        ),
      ),
    );
  }
}

/// The user's own picture in the app bar — never a stock image, which reads
/// as somebody else's face on the account.
///
/// Picture → initials → person icon, in that order of what is known.
class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.initials});

  final String? url;
  final String? initials;

  static const Color _ink = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final letters = initials?.trim() ?? '';
    final fallback = letters.isEmpty
        ? Icon(Icons.person, color: _ink, size: context.rr(18))
        : Center(
            child: Text(
              letters,
              // Fixed-size badge: initials must not grow with the text scale.
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: _ink,
                fontSize: context.rr(13),
                fontWeight: FontWeight.w800,
              ),
            ),
          );

    final address = url;
    if (address == null) return fallback;
    return CachedNetworkImage(
      imageUrl: address,
      fit: BoxFit.cover,
      memCacheWidth:
          (context.rr(38) * MediaQuery.devicePixelRatioOf(context)).round(),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
