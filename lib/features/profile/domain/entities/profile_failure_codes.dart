/// Failure codes the profile feature raises itself, alongside the server's
/// own (`ApiErrorCodes.profileUpdateEmpty`, `avatarTooLarge`, …).
abstract final class ProfileFailureCodes {
  /// The picked file could not be decoded as an image.
  static const avatarUnreadable = 'Client.AvatarUnreadable';
}
