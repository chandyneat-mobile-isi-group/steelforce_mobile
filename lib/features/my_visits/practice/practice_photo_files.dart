/// Deletes a photo file captured during a practice lesson.
///
/// Platform-selected: mobile removes the file; web has none to remove (a
/// captured image there is a session-lifetime `blob:` URL that writes nothing
/// to origin storage), so it is a no-op.
library;

export 'practice_photo_files_web.dart'
    if (dart.library.io) 'practice_photo_files_native.dart';
