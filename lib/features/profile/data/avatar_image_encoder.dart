import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Prepares a picked photograph for `PUT /users/me/profile`.
///
/// Three jobs, all required by the contract
/// (`docs/feature/authentication/profile.md` §3 and Limitations):
///
///  * **Downscale** to [maxEdge] — the avatar renders at header size, and a
///    full camera frame is a slow upload on a provincial connection.
///  * **Re-encode as JPEG** — whatever the source format, the upload is then
///    always one the server accepts, and far under its 2 MB ceiling.
///  * **Strip EXIF.** The server stores the bytes as sent and serves them
///    anonymously; a photo taken in the field would otherwise publish the GPS
///    position it was taken at. Orientation is baked into the pixels first so
///    removing the tag does not turn the picture sideways.
abstract final class AvatarImageEncoder {
  static const int maxEdge = 512;
  static const int quality = 85;

  /// Runs off the UI thread. Throws [FormatException] when [bytes] is not an
  /// image this build can decode (e.g. HEIC on some devices).
  static Future<Uint8List> encode(Uint8List bytes) =>
      compute(encodeSync, bytes);

  @visibleForTesting
  static Uint8List encodeSync(Uint8List bytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      // Truncated or foreign bytes make some decoders throw (a RangeError,
      // not a null) — every way of "not an image" must reach the caller as
      // the one exception it handles.
      decoded = null;
    }
    if (decoded == null) {
      throw const FormatException('The picked file is not a readable image.');
    }

    var image = img.bakeOrientation(decoded);
    if (image.width > maxEdge || image.height > maxEdge) {
      final landscape = image.width >= image.height;
      image = img.copyResize(
        image,
        width: landscape ? maxEdge : null,
        height: landscape ? null : maxEdge,
        interpolation: img.Interpolation.average,
      );
    }

    // Last, so nothing above can carry a tag back in.
    image.exif = img.ExifData();
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}
