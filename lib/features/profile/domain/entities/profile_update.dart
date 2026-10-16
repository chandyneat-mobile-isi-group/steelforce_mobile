import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A change to the signed-in rep's own profile picture — the only part of
/// their profile they may change. Name, job title, contact details and
/// assignments are owned by HR and an administrator.
class ProfileUpdate extends Equatable {
  const ProfileUpdate({
    this.avatarBytes,
    this.removeAvatar = false,
  }) : assert(
          avatarBytes == null || !removeAvatar,
          'A new picture and removing the picture are opposite requests.',
        );

  /// The picture as picked. The data layer downscales and re-encodes it
  /// before upload.
  final Uint8List? avatarBytes;

  final bool removeAvatar;

  /// True when there is nothing to send, so the client must not send it.
  bool get isEmpty => avatarBytes == null && !removeAvatar;

  @override
  List<Object?> get props => [avatarBytes?.length, removeAvatar];
}
