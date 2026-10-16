/// Platform-selected OS description for the login device block.
///
/// Both sides expose `String? readOsVersion()`. Native reads the real kernel
/// string; web returns null, because a browser will not tell us and a guessed
/// value in a session record is worse than an absent one — support staff read
/// that field to identify a handset someone has lost.
library;

export 'device_os_web.dart' if (dart.library.io) 'device_os_native.dart';
