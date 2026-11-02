import 'dart:io';

import 'package:steelforce/core/network/interceptors/work_mode_interceptor.dart';

/// See `request_reach.dart`. [WorkModeBlocked] is refused before sending.
bool neverReachedServer(Object? error) =>
    error is SocketException || error is WorkModeBlocked;
