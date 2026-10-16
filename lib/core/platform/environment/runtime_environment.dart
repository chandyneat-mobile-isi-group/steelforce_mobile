/// Platform-selected answer to "is this a simulator?".
///
/// Both sides expose `bool get isIosSimulator` and `bool get isMobilePlatform`.
/// Native inspects the process environment; web answers false, because a
/// browser is neither a simulator nor a handset and the distinction only
/// matters for hardware the browser does not expose anyway.
library;

export 'runtime_environment_web.dart'
    if (dart.library.io) 'runtime_environment_native.dart';
