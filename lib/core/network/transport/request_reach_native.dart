import 'dart:io';

/// See `request_reach.dart`.
bool neverReachedServer(Object? error) => error is SocketException;
