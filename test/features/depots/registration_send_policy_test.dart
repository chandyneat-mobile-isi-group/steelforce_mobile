import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/depots/data/repositories/outbox/registration_send_policy.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';

/// The retry rules on their own. The drain tests in
/// `depot_registration_outbox_test.dart` cover how each decision is applied.
void main() {
  SendFailureDecision decide(Failure f, [int attempts = 1]) =>
      RegistrationSendPolicy.onSendFailure(f, attempts);

  test('nothing sent: requeued untouched, and the drain stops', () {
    for (final f in [
      const NetworkFailure(message: 'x'),
      const ServerUnreachableFailure(message: 'x'),
    ]) {
      expect(
        decide(f),
        isA<Requeue>()
            .having(
                (d) => d.reason, 'reason', RegistrationSendPolicy.reasonOffline)
            .having((d) => d.backOff, 'backOff', isFalse)
            .having((d) => d.stopsDrain, 'stopsDrain', isTrue),
      );
    }
    expect(
      decide(const AuthenticationFailure(message: 'x')),
      isA<Requeue>().having(
          (d) => d.reason, 'reason', RegistrationSendPolicy.reasonSignedOut),
    );
  });

  test('a gateway refusal backs off until the cap, then goes to the rep', () {
    const busy = ServerFailure(message: 'busy', statusCode: 503);
    expect(
      decide(busy, RegistrationSendPolicy.maxGatewayAttempts - 1),
      isA<Requeue>().having((d) => d.backOff, 'backOff', isTrue).having(
          (d) => d.reason, 'reason', RegistrationSendPolicy.reasonServerBusy),
    );
    expect(
      decide(busy, RegistrationSendPolicy.maxGatewayAttempts),
      isA<HandToRep>()
          .having((d) => d.status, 'status',
              DepotRegistrationQueueStatus.needsReview)
          .having((d) => d.message, 'message', 'busy')
          .having((d) => d.stopsDrain, 'stopsDrain', isFalse),
    );
  });

  test('a 5xx that may have landed goes to review without a message', () {
    for (final code in [500, 504]) {
      expect(
        decide(ServerFailure(message: 'boom', statusCode: code)),
        isA<HandToRep>()
            .having((d) => d.status, 'status',
                DepotRegistrationQueueStatus.needsReview)
            .having((d) => d.message, 'message', isNull),
      );
    }
  });

  test('a refusal is rejected with its own wording', () {
    for (final f in [
      const ServerFailure(message: 'Duplicate VAT', statusCode: 422),
      const ServerFailure(message: 'Duplicate VAT'),
      const CacheFailure(message: 'Duplicate VAT'),
    ]) {
      expect(
        decide(f),
        isA<HandToRep>()
            .having((d) => d.status, 'status',
                DepotRegistrationQueueStatus.rejected)
            .having((d) => d.message, 'message', 'Duplicate VAT'),
      );
    }
  });

  test('backoff doubles from 30 s, caps at 30 min, adds at most 20%', () {
    final none = _FixedRandom(0);
    final most = _FixedRandom(0.999999);
    expect(RegistrationSendPolicy.backoff(1, none).inSeconds, 30);
    expect(RegistrationSendPolicy.backoff(2, none).inSeconds, 60);
    expect(RegistrationSendPolicy.backoff(4, none).inSeconds, 240);
    expect(RegistrationSendPolicy.backoff(20, none).inSeconds, 1800);
    expect(RegistrationSendPolicy.backoff(20, most).inSeconds, 2160);
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}
