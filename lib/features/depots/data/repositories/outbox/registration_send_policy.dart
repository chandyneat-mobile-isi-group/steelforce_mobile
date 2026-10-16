import 'dart:math';

import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';

/// The registration outbox's limits and retry rules, kept apart from the
/// drain that applies them so the policy reads (and is tested) on its own.
/// The policy itself is described on `DepotRegistrationOutbox`.
abstract final class RegistrationSendPolicy {
  /// A gateway 5xx is retried this many times before the row is handed to the
  /// rep. Nothing reached SAP on those, so they are safe — but a server that
  /// fails eight times running needs a human, not a ninth attempt.
  static const int maxGatewayAttempts = 8;

  /// Photo upload rounds before the photographs are given up on. The depot
  /// exists by then, so this costs evidence (refiled from the detail screen),
  /// never a registration.
  static const int maxPhotoAttempts = 10;

  /// The write timeout is 60 s; a row still `sending` after this was left
  /// behind by a process that died mid-request.
  static const Duration staleClaim = Duration(minutes: 3);

  /// Several photographs on a slow link can take far longer than one request,
  /// so an upload claim is given longer before it is presumed dead.
  static const Duration staleUploadClaim = Duration(minutes: 20);

  /// Why a queued row has not gone yet — localization keys, shown on the row.
  static const String reasonOffline = 'sync_center.depot.reason.offline';
  static const String reasonSignedOut = 'sync_center.depot.reason.signed_out';
  static const String reasonServerBusy = 'sync_center.depot.reason.server_busy';

  /// `30 s · 2^(n-1)`, capped at 30 min, plus up to 20% jitter (§4).
  static Duration backoff(int attempts, [Random? random]) {
    final seconds = min(30 * pow(2, max(0, attempts - 1)).toInt(), 1800);
    final jitter = (seconds * 0.2 * (random ?? Random()).nextDouble()).round();
    return Duration(seconds: seconds + jitter);
  }

  /// What to do with a registration whose send just failed on its
  /// [attempts]th try.
  static SendFailureDecision onSendFailure(Failure failure, int attempts) {
    switch (failure) {
      // Never left the handset. Back in the queue untouched, and the drain
      // stops: the rows behind it would fail identically.
      case NetworkFailure():
      case ServerUnreachableFailure():
        return const Requeue(reason: reasonOffline);

      // The session needs the rep (sign in again). Nothing was sent.
      case AuthenticationFailure():
        return const Requeue(reason: reasonSignedOut);

      case ServerFailure(:final statusCode):
        // The gateway refused it before SAP. Safe to resend, with backoff.
        if (isSafeToResendServerError(statusCode)) {
          if (attempts >= maxGatewayAttempts) {
            return HandToRep(
              DepotRegistrationQueueStatus.needsReview,
              failure.message,
            );
          }
          // The gateway is struggling. Sending the next registration straight
          // into it would only add load; everything waits for this backoff.
          return const Requeue(reason: reasonServerBusy, backOff: true);
        }
        // Any other 5xx — a 504 (no answer), a 500 (raised after SAP may have
        // written it) — may have landed. The rep checks first.
        if (statusCode != null && statusCode >= 500) {
          return const HandToRep(DepotRegistrationQueueStatus.needsReview);
        }
        // SAP (or the app's own pre-send check) said no.
        return HandToRep(
          DepotRegistrationQueueStatus.rejected,
          failure.message,
        );

      case CacheFailure():
      case DepotStopInformationUnavailableFailure():
      case AdHocVisitRefusedFailure():
        return HandToRep(
          DepotRegistrationQueueStatus.rejected,
          failure.message,
        );
    }
  }
}

/// The outcome of [RegistrationSendPolicy.onSendFailure].
sealed class SendFailureDecision {
  const SendFailureDecision();

  /// The rows behind this one would fail the same way, so the drain ends.
  bool get stopsDrain;
}

/// Back in the queue. With [backOff], the attempt is counted and the row waits
/// out a backoff; without, it is retried at the next drain as if untried.
final class Requeue extends SendFailureDecision {
  const Requeue({required this.reason, this.backOff = false});

  /// Localization key for why it has not gone yet, shown on the row.
  final String reason;
  final bool backOff;

  @override
  bool get stopsDrain => true;
}

/// Parked for the rep, who decides — the drain never sends it again by itself.
final class HandToRep extends SendFailureDecision {
  const HandToRep(this.status, [this.message]);

  final DepotRegistrationQueueStatus status;
  final String? message;

  @override
  bool get stopsDrain => false;
}
