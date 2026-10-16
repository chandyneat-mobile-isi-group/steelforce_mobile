import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_photo_viewer.dart';

/// Who is signed in: picture, name, job title and employee number, with the
/// one action that changes them pinned to the picture.
///
/// Phone: picture left, identity right — the header stays short so the menu
/// below starts above the fold. Tablet: stacked and centred, for the sidebar.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.onEdit,
    this.isTablet = false,
    this.showEdit = true,
  });

  final WorkerProfile profile;

  /// Null while a save is in flight, which disables the button.
  final VoidCallback? onEdit;
  final bool isTablet;

  /// False hides the edit button altogether — the picture cannot be changed
  /// in this build.
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final avatar = _AvatarWithEdit(
      profile: profile,
      onEdit: onEdit,
      showEdit: showEdit,
      size: isTablet ? 120 : context.rr(88),
    );

    if (isTablet) {
      return Column(
        children: [
          avatar,
          SizedBox(height: context.rh(18)),
          _Identity(profile: profile, centered: true),
        ],
      );
    }

    return Row(
      children: [
        avatar,
        SizedBox(width: context.rw(18)),
        // Expanded, so a long or Khmer name wraps instead of overflowing.
        Expanded(child: _Identity(profile: profile, centered: false)),
      ],
    );
  }
}

class _AvatarWithEdit extends StatelessWidget {
  const _AvatarWithEdit({
    required this.profile,
    required this.onEdit,
    required this.showEdit,
    required this.size,
  });

  final WorkerProfile profile;
  final VoidCallback? onEdit;
  final bool showEdit;
  final double size;

  /// With a picture, tapping it opens it full screen. Initials have nothing to
  /// enlarge, so they stay a plain image.
  Widget _tappableAvatar(BuildContext context) {
    final avatar = ProfileAvatar(
      // The small square thumbnail fills the circle; the full-size photo is
      // kept for the full-screen view below.
      url: profile.avatarThumbnailUrl ?? profile.avatarUrl,
      initials: profile.initials,
      size: size,
      semanticLabel:
          'profile.avatar_label'.trParams({'name': profile.fullName}),
    );
    final url = profile.avatarUrl;
    if (url == null || url.isEmpty) return avatar;

    final heroTag = profilePhotoHeroTag(profile.id);
    return Semantics(
      button: true,
      hint: 'profile.view_photo'.tr,
      child: GestureDetector(
        onTap: () => showProfilePhotoViewer(
          context,
          url: url,
          heroTag: heroTag,
          name: profile.fullName,
        ),
        child: Hero(tag: heroTag, child: avatar),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!showEdit) return _tappableAvatar(context);
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _tappableAvatar(context),
        Positioned(
          right: -context.rw(10),
          // The chip draws 32dp tall inside a padded 48dp tap target. Sitting
          // this low keeps that invisible margin off the middle of the photo,
          // which is where a tap means "show me the picture", not "edit".
          bottom: -context.rh(12),
          child: OutlinedButton.icon(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.card,
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: colors.border),
              minimumSize: const Size(0, 32),
              padding: EdgeInsets.symmetric(horizontal: context.rw(10)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(Icons.edit_outlined, size: context.rr(15)),
            label: Text(
              'profile.edit'.tr,
              style: TextStyle(
                fontSize: context.rsp(12.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile, required this.centered});

  final WorkerProfile profile;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final title = profile.title;
    final align = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          profile.fullName,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: context.rsp(centered ? 21 : 19),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.2,
          ),
        ),
        if (profile.khmerName case final khmer?) ...[
          SizedBox(height: context.rh(2)),
          Text(
            khmer,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: context.rsp(centered ? 16 : 15),
              fontWeight: FontWeight.w600,
              // Khmer script needs more line height than Latin.
              height: 1.5,
            ),
          ),
        ],
        if (title.isNotEmpty) ...[
          SizedBox(height: context.rh(4)),
          Text(
            title,
            textAlign: align,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (profile.employeeCode.isNotEmpty) ...[
          SizedBox(height: context.rh(8)),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${'profile.employee_id'.tr}  ',
                style: TextStyle(color: colors.textSecondary),
              ),
              TextSpan(
                text: profile.employeeCode,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ]),
            textAlign: align,
            style: TextStyle(fontSize: context.rsp(12.5), letterSpacing: 0.2),
          ),
        ],
      ],
    );
  }
}
