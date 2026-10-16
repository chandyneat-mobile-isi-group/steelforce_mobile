import 'dart:async';

import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/my_visits/data/local/check_out_reason_store.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/repositories/check_out_reason_repository.dart';

class CheckOutReasonRepositoryImpl implements CheckOutReasonRepository {
  const CheckOutReasonRepositoryImpl({
    required VisitCheckRemoteDataSource remote,
    required CheckOutReasonStore store,
    required NetworkInfo network,
    AppLogger? logger,
    this.wait = const Duration(seconds: 4),
  })  : _remote = remote,
        _store = store,
        _network = network,
        _logger = logger;

  final VisitCheckRemoteDataSource _remote;
  final CheckOutReasonStore _store;
  final NetworkInfo _network;
  final AppLogger? _logger;

  /// The rep is looking at the check-out sheet; a slow answer falls back to
  /// the cached list rather than holding them.
  final Duration wait;

  @override
  Future<List<NoOrderReason>> getReasons() async {
    if (await _network.isConnected) {
      try {
        final fresh = await _remote.fetchCheckOutReasons().timeout(wait);
        if (fresh.isNotEmpty) {
          await _store.write(fresh);
          return _withOther(fresh);
        }
      } on ApiException catch (e) {
        _logger?.warning('visit.check_out_reasons.failed',
            fields: {'code': e.error.code, 'status': e.error.statusCode});
      } on TimeoutException {
        _logger?.info('visit.check_out_reasons.timeout');
      } catch (e, stack) {
        // A malformed answer must not cost the rep their check-out.
        _logger?.error('visit.check_out_reasons.unreadable',
            error: e, stackTrace: stack);
      }
    }
    return _withOther(_store.read());
  }

  /// `other` always exists (§6) — and before the first fetch it is the only
  /// reason there is.
  static List<NoOrderReason> _withOther(List<NoOrderReason> reasons) => [
        ...reasons,
        if (!reasons.any((r) => r.code == NoOrderReason.otherCode))
          NoOrderReason.other,
      ]..sort((a, b) => a.sort.compareTo(b.sort));
}
