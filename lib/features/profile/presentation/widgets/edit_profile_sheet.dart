import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/profile/domain/entities/profile_failure_codes.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';
import 'package:steelforce/shared/widgets/keyboard_aware_scroll_view.dart';

/// Opens the profile editor. Resolves to true when a change was saved.
///
/// The rep can change only their **profile picture** here. Name, job title
/// and the rest of the record are managed by HR and shown read-only in My
/// details; the language follows the app's own setting.
///
/// The sheet saves through [cubit] itself and stays open on failure, so a
/// dropped connection never throws away the picture that was picked.
Future<bool?> showEditProfileSheet({
  required BuildContext context,
  required WorkerProfile profile,
  required ProfileCubit cubit,
  required ImageCaptureService imageCapture,
}) {
  final sheet = _EditProfileSheet(
    profile: profile,
    cubit: cubit,
    imageCapture: imageCapture,
  );

  // Width, not device type: a wide window gets a centred dialog instead of a
  // sheet stretched edge to edge.
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.appColors.surfaceSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: sheet,
        ),
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.appColors.surfaceSoft,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    // AppBottomSheet supplies the keyboard inset, the safe area and the
    // height cap.
    builder: (_) => AppBottomSheet(child: sheet),
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.profile,
    required this.cubit,
    required this.imageCapture,
  });

  final WorkerProfile profile;
  final ProfileCubit cubit;
  final ImageCaptureService imageCapture;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  Uint8List? _pickedPhoto;
  bool _removePhoto = false;
  bool _saving = false;
  String? _error;

  /// The picture change, if any — nothing else is editable here.
  ProfileUpdate get _update => ProfileUpdate(
        avatarBytes: _pickedPhoto,
        removeAvatar: _removePhoto,
      );

  Future<void> _save() async {
    final update = _update;
    if (update.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await widget.cubit.updateProfile(update);
    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = profileFailureMessage(failure);
    });
  }

  Future<void> _choosePhoto() async {
    final canRemove = !_removePhoto &&
        (_pickedPhoto != null || widget.profile.avatarUrl != null);

    final choice = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: context.appColors.surfaceSoft,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.imageCapture.isAvailable) ...[
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: Text('profile.take_photo'.tr),
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text('profile.choose_photo'.tr),
                onTap: () => Navigator.pop(context, _PhotoAction.gallery),
              ),
            ],
            if (canRemove)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: Text(
                  'profile.remove_photo'.tr,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == _PhotoAction.remove) {
      setState(() {
        _pickedPhoto = null;
        // Removing a picture that was only picked here just discards it;
        // there is nothing on the server to delete.
        _removePhoto = widget.profile.avatarUrl != null;
        _error = null;
      });
      return;
    }

    try {
      // A first, cheap downscale on the platform side; the data layer does
      // the exact resize, re-encode and metadata strip before upload.
      final file = await widget.imageCapture.pick(
        choice == _PhotoAction.camera
            ? ImageCaptureSource.camera
            : ImageCaptureSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedPhoto = bytes;
        _removePhoto = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'profile.error_photo_unreadable'.tr);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final hasChanges = !_update.isEmpty;
    final showsPhoto = _pickedPhoto != null ||
        (!_removePhoto && widget.profile.avatarUrl != null);

    return PopScope(
      // Not while saving: closing mid-request would hide the outcome.
      canPop: !_saving,
      child: KeyboardAwareScrollView(
        padding: EdgeInsets.fromLTRB(
            context.rw(20), context.rh(8), context.rw(20), context.rh(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'profile.edit_profile'.tr,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: context.rsp(19),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'profile.cancel'.tr,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: context.rh(12)),
            _PhotoPicker(
              profile: widget.profile,
              previewBytes: _pickedPhoto,
              showsPhoto: showsPhoto,
              onTap: _saving ? null : _choosePhoto,
            ),
            if (_removePhoto) ...[
              SizedBox(height: context.rh(6)),
              Text(
                'profile.photo_will_be_removed'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(12)),
              ),
            ],
            if (_error case final message?) ...[
              SizedBox(height: context.rh(14)),
              _ErrorBanner(message: message),
            ],
            SizedBox(height: context.rh(20)),
            FilledButton(
              onPressed: hasChanges && !_saving ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary),
                        ),
                        const SizedBox(width: 10),
                        Text('profile.saving'.tr),
                      ],
                    )
                  : Text(
                      hasChanges
                          ? 'profile.save_changes'.tr
                          : 'profile.no_changes'.tr,
                      style: TextStyle(
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.profile,
    required this.previewBytes,
    required this.showsPhoto,
    required this.onTap,
  });

  final WorkerProfile profile;
  final Uint8List? previewBytes;
  final bool showsPhoto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = context.rr(96);

    return Column(
      children: [
        Semantics(
          button: true,
          label: 'profile.change_photo'.tr,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfileAvatar(
                  initials: profile.initials,
                  size: size,
                  url: showsPhoto ? profile.avatarUrl : null,
                  previewBytes: previewBytes,
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.appColors.surfaceSoft, width: 2),
                    ),
                    child: Icon(Icons.photo_camera_rounded,
                        size: 16, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text('profile.change_photo'.tr),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(12), vertical: context.rh(10)),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: scheme.error, size: context.rr(18)),
            SizedBox(width: context.rw(8)),
            Expanded(
              child: Text(
                message,
                style:
                    TextStyle(color: scheme.error, fontSize: context.rsp(13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What to tell the user about a failed save — never the raw server text,
/// which is English-only and written for developers.
String profileFailureMessage(Failure failure) {
  if (failure is NetworkFailure || failure is ServerUnreachableFailure) {
    return 'profile.error_offline'.tr;
  }
  final code = failure is ServerFailure ? failure.code : null;
  return switch (code) {
    ApiErrorCodes.profileUpdateEmpty => 'profile.no_changes'.tr,
    ApiErrorCodes.avatarExtensionNotAllowed ||
    ApiErrorCodes.avatarContentTypeMismatch =>
      'profile.error_photo_type'.tr,
    ApiErrorCodes.avatarTooLarge => 'profile.error_photo_size'.tr,
    ProfileFailureCodes.avatarUnreadable => 'profile.error_photo_unreadable'.tr,
    ApiErrorCodes.avatarStorageFailed => 'profile.error_photo_storage'.tr,
    ApiErrorCodes.validation => 'profile.error_validation'.tr,
    _ => switch (failure.statusCode) {
        // `/users/profile-photo` reports by status: the photo route's codes
        // are not the old profile-edit ones above.
        413 => 'profile.error_photo_size'.tr,
        400 => 'profile.error_photo_type'.tr,
        429 => 'profile.error_too_many'.tr,
        _ => 'profile.updated_failure'.tr,
      },
  };
}
