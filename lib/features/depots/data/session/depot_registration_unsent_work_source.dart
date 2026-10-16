import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';

/// Depot registrations still in the outbox — queued, uploading photographs,
/// or waiting on the rep in the Sync Center.
///
/// Every one counts, including those waiting on the rep: sign-out wipes the
/// database, and a registration the rep has not yet checked or fixed would be
/// destroyed with it. The Sync Center offers Retry, Fix or Discard for those,
/// so a rep is never trapped.
class DepotRegistrationUnsentWorkSource
    implements UnsentWorkSource, UnsentWorkBreakdown {
  const DepotRegistrationUnsentWorkSource(this._outbox);

  final DepotRegistrationOutbox _outbox;

  @override
  String get debugName => 'depots.registration_queue';

  @override
  Future<int> countUnsent() => _outbox.countUnsent();

  @override
  Future<int> countSendable() => _outbox.countSendable();

  @override
  Future<void> sendNow() => _outbox.drain();

  @override
  Future<List<UnsentWorkCount>> breakdown() async {
    final unsent = await countUnsent();
    final sendable = await countSendable();
    return [
      UnsentWorkCount(UnsentWorkKind.depotRegistrations, unsent,
          needsAction: unsent - sendable),
    ];
  }
}
