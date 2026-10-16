import 'package:steelforce/core/logging/app_logger.dart';

/// Implemented by each feature that keeps rep work on the device until the
/// server has it — queued quotations, captured visit records, ad hoc visit
/// requests.
///
/// Sign-out wipes the whole local database, so it is refused while any of this
/// is outstanding: work saved offline would otherwise be destroyed without
/// ever reaching the server. Same inversion as [SessionScopedStore] —
/// `authentication` never imports `order` or `my_visits`.
abstract interface class UnsentWorkSource {
  /// Used only in logs.
  String get debugName;

  /// Items saved on this device that the server does not hold yet.
  Future<int> countUnsent();

  /// The part of [countUnsent] that [sendNow] can still deliver without the
  /// rep — excluding items parked for a decision (a conflict, a registration
  /// whose outcome is unknown). The sync engine retries while this is above
  /// zero; [countUnsent] is what blocks sign-out.
  Future<int> countSendable();

  /// Tries to send them now. Never throws; an offline device simply sends
  /// nothing and [countUnsent] stays where it was.
  Future<void> sendNow();
}

/// What kind of work is waiting, for the sign-out dialog's preview. Listed in
/// the order the sync engine sends them.
enum UnsentWorkKind {
  depotRegistrations,
  adHocVisits,
  checkIns,
  quotations,
  checkOuts,
  visitRecords,
  other,
}

/// How many items of one [UnsentWorkKind] are still on the device.
class UnsentWorkCount {
  const UnsentWorkCount(this.kind, this.unsent, {this.needsAction = 0});

  final UnsentWorkKind kind;
  final int unsent;

  /// The part of [unsent] that will not go by itself — it waits for the rep
  /// (a failed quotation, a registration whose outcome is unknown).
  final int needsAction;
}

/// Optionally implemented by an [UnsentWorkSource] that can say what its
/// items are. A source without it shows as [UnsentWorkKind.other].
abstract interface class UnsentWorkBreakdown {
  Future<List<UnsentWorkCount>> breakdown();
}

/// Sums every registered [UnsentWorkSource].
class UnsentWorkService {
  const UnsentWorkService(this._sources, this._logger);

  final List<UnsentWorkSource> _sources;
  final AppLogger _logger;

  Future<int> count() async {
    var total = 0;
    for (final source in _sources) {
      try {
        total += await source.countUnsent();
      } catch (e, stack) {
        // A store that cannot even be read holds nothing that could still be
        // sent from it, and refusing sign-out forever over it would trap the
        // rep in their session. Logged loudly instead.
        _logger.error('Unsent-work count failed for ${source.debugName}',
            error: e, stackTrace: stack);
      }
    }
    return total;
  }

  /// [count], split by kind and in send order, leaving out kinds with
  /// nothing waiting.
  Future<List<UnsentWorkCount>> breakdown() async {
    final unsent = <UnsentWorkKind, int>{};
    final needsAction = <UnsentWorkKind, int>{};
    for (final source in _sources) {
      try {
        final parts = source is UnsentWorkBreakdown
            ? await (source as UnsentWorkBreakdown).breakdown()
            : [
                UnsentWorkCount(
                    UnsentWorkKind.other, await source.countUnsent())
              ];
        for (final part in parts) {
          unsent.update(part.kind, (n) => n + part.unsent,
              ifAbsent: () => part.unsent);
          needsAction.update(part.kind, (n) => n + part.needsAction,
              ifAbsent: () => part.needsAction);
        }
      } catch (e, stack) {
        _logger.error('Unsent-work breakdown failed for ${source.debugName}',
            error: e, stackTrace: stack);
      }
    }
    return [
      for (final kind in UnsentWorkKind.values)
        if ((unsent[kind] ?? 0) > 0)
          UnsentWorkCount(kind, unsent[kind]!,
              needsAction: needsAction[kind] ?? 0),
    ];
  }

  /// What could still go out without the rep. See
  /// [UnsentWorkSource.countSendable].
  Future<int> countSendable() async {
    var total = 0;
    for (final source in _sources) {
      try {
        total += await source.countSendable();
      } catch (e, stack) {
        _logger.error('Sendable count failed for ${source.debugName}',
            error: e, stackTrace: stack);
      }
    }
    return total;
  }

  /// Sends every source registered ahead of the one named [debugName], in
  /// order — for a feature that sends on its own schedule but must not
  /// overtake work the server needs first (an order before its stop's
  /// check-in). Sends nothing if no source has that name.
  Future<void> sendBefore(String debugName) async {
    final index = _sources.indexWhere((s) => s.debugName == debugName);
    for (final source in _sources.take(index < 0 ? 0 : index)) {
      try {
        await source.sendNow();
      } catch (e, stack) {
        _logger.error('Unsent-work send failed for ${source.debugName}',
            error: e, stackTrace: stack);
      }
    }
  }

  /// Runs every source's send, in registration order, then answers what is
  /// still left. The order is the order the server receives things in.
  Future<int> sendAll() async {
    for (final source in _sources) {
      try {
        await source.sendNow();
      } catch (e, stack) {
        _logger.error('Unsent-work send failed for ${source.debugName}',
            error: e, stackTrace: stack);
      }
    }
    return count();
  }
}
