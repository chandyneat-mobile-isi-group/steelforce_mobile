/// Web: not a simulator, not a handset.
///
/// A browser exposes `getUserMedia` rather than a device camera, and
/// `image_picker` falls back to a file input there — which works, needs no
/// stand-in, and is what a web user expects.
bool get isIosSimulator => false;

bool get isMobilePlatform => false;

bool get isAndroidEmulator => false;
