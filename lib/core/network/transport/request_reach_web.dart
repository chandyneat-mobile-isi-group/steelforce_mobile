/// See `request_reach.dart`. A browser cannot tell a refused connection from a
/// dropped response, so nothing is ever provably unsent.
bool neverReachedServer(Object? error) => false;
