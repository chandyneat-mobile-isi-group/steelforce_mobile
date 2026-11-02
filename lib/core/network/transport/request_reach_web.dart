import 'package:steelforce/core/network/interceptors/work_mode_interceptor.dart';

/// See `request_reach.dart`. A browser cannot tell a refused connection from a
/// dropped response, so a network failure is never provably unsent — only a
/// request offline mode refused before it left ([WorkModeBlocked]) is.
bool neverReachedServer(Object? error) => error is WorkModeBlocked;
