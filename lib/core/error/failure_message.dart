import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';

/// What to tell the rep about a [Failure], in the active language.
///
/// [Failure.message] has two very different sources. A server failure carries
/// the API's own message, already localised against the `Accept-Language`
/// header, and is meant to be shown. A local one is written by the data layer
/// for the log — "Failed to load route: SqliteException(…)" — in English, with
/// the exception text attached. Shown as is, a Khmer-speaking rep reads a
/// stack fragment.
///
/// So local failures speak only through translation keys: a [CacheFailure]
/// whose message is a key ('depots.error.not_found') shows that key's text,
/// and anything else shows the generic local-data message.
extension FailureUserMessage on Failure {
  String get userMessage => switch (this) {
        NetworkFailure() => 'common.network_unavailable'.tr,
        ServerUnreachableFailure() => 'common.server_unreachable'.tr,
        DepotStopInformationUnavailableFailure() =>
          'common.outlet_details_unavailable'.tr,
        CacheFailure(:final message) =>
          _isKey(message) ? message.tr : 'common.local_data_error'.tr,
        _ => message.trim().isEmpty
            ? 'common.generic_error'.tr
            // `.tr` leaves server text untouched and resolves a key.
            : message.tr,
      };
}

final _keyShape = RegExp(r'^[a-z][a-z0-9_]*(\.[a-zA-Z0-9_]+)+$');

bool _isKey(String message) => _keyShape.hasMatch(message);
