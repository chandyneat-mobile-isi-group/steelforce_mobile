import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/routes_params.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';

/// Records a check-in the rules have allowed: the local save, the offer to
/// the server, then the stop status — in that order, each step answering
/// for its own failure.
class CheckInSubmission {
  const CheckInSubmission({
    required CheckIn checkIn,
    required UpdateStopStatus updateStopStatus,
    required void Function(Object error, StackTrace stackTrace) onError,
    SendCheckIn? sendCheckIn,
  })  : _checkIn = checkIn,
        _updateStopStatus = updateStopStatus,
        _onError = onError,
        _sendCheckIn = sendCheckIn;

  final CheckIn _checkIn;
  final UpdateStopStatus _updateStopStatus;

  /// Reports a failure without its message, which can wrap raw database text.
  final void Function(Object error, StackTrace stackTrace) _onError;

  /// Offers a saved check-in to the server straight away. Optional so the
  /// local-only construction sites (tests) still compile; without it the
  /// check-in waits for the batch push.
  final SendCheckIn? _sendCheckIn;

  Future<CheckInOutcome> submit(CheckInRecord record) async {
    // The local save is the check-in. If it did not land, nothing was
    // recorded and the rep must be told so — never shown a success.
    //
    // `CheckIn` reports a failed write as a `Failed` result, not a throw. The
    // handler used to only `catch`, so a `CacheFailure` from the repository
    // sailed straight past it: the stop was marked checked in on screen, the
    // rep was moved on into the visit, and no check-in row existed to push.
    // Both shapes are now answered the same way: a typed
    // `checkInSaveFailed` state the screen renders as a localized message.
    if (await _saveFailed(record)) return const CheckInSaveFailed();

    // Saved. Online, the server sees it now; offline it waits for the next
    // sync and the rep carries on regardless. Only a definite refusal stops
    // the check-in — the repository has already dropped the row then.
    final refusal = await _offerToServer(record);
    if (refusal != null) return CheckInRefused(refusal);

    // The check-in row exists now. If the status update fails, still move the
    // rep on — retrying would write a second check-in row for the same visit.
    try {
      final statusResult = await _updateStopStatus(UpdateStopStatusParams(
          stopId: record.stopId,
          status: VisitStatus.checkedIn,
          actualArrival: record.timestamp));
      // The failure's message wraps raw database text, which can quote row
      // values — only the fact of the failure is reported.
      if (statusResult is Failed) {
        _onError(StateError('stop status not saved'), StackTrace.current);
      }
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
    return const CheckedIn();
  }

  /// Writes the check-in row. Returns true when it was **not** saved — either
  /// a `Failed` result or a throw — so the caller can refuse to report success.
  Future<bool> _saveFailed(CheckInRecord record) async {
    try {
      final result = await _checkIn(record);
      if (result is Failed) {
        // Not the failure's message: it wraps raw database text.
        _onError(StateError('check-in not saved'), StackTrace.current);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
      return true;
    }
  }

  /// The server's definite refusal of [record], or null — sent, queued, or
  /// not wired. A failure to even ask is never a refusal.
  Future<VisitSendStatus?> _offerToServer(CheckInRecord record) async {
    final send = _sendCheckIn;
    if (send == null) return null;
    try {
      final result = await send(record);
      return result.when(
        success: (r) => r.refused ? r.status : null,
        failure: (_) => null,
      );
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
      return null;
    }
  }
}

/// How [CheckInSubmission.submit] ended.
sealed class CheckInOutcome {
  const CheckInOutcome();
}

/// Nothing was recorded.
final class CheckInSaveFailed extends CheckInOutcome {
  const CheckInSaveFailed();
}

/// The server definitely refused it; the local row is already gone.
final class CheckInRefused extends CheckInOutcome {
  const CheckInRefused(this.status);
  final VisitSendStatus status;
}

/// Saved locally, sent or queued; the stop is checked in.
final class CheckedIn extends CheckInOutcome {
  const CheckedIn();
}
