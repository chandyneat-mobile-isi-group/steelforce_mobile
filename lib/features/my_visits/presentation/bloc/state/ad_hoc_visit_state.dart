import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';

/// State of the "add a depot to today" action.
///
/// Modelled as four explicit states plus a one-shot [effect], rather than a
/// nullable field and a bool. The effect exists because three of the outcomes
/// are things the *screen* must do once — navigate to an existing stop, show a
/// message — and re-running them on every rebuild would bounce the rep around.
final class AdHocVisitState extends Equatable {
  const AdHocVisitState({
    this.status = AdHocVisitStatus.idle,
    this.pending = const [],
    this.depotIdsOnDay = const {},
    this.effect,
    this.hidden = false,
  });

  final AdHocVisitStatus status;

  /// Requests waiting to reach the server, oldest first. Rendered as pending
  /// rows — never as tappable cards, because they carry no stop id yet.
  final List<PendingAdHocVisit> pending;

  /// Depots already on the selected day. The picker hides these: offering a
  /// tap whose only possible answer is "already on today's route" wastes a
  /// round trip and reads as a failure.
  final Set<String> depotIdsOnDay;

  /// Consumed once by the listener, then cleared. Null most of the time.
  final AdHocVisitEffect? effect;

  /// True once the server has said this account is not a field rep
  /// (`Visit.RepNotAuthorized`). The action is hidden for the rest of the
  /// session. **This is not a sign-out** — a 403 never justifies dropping the
  /// session.
  final bool hidden;

  bool get isSubmitting => status == AdHocVisitStatus.submitting;

  AdHocVisitState copyWith({
    AdHocVisitStatus? status,
    List<PendingAdHocVisit>? pending,
    Set<String>? depotIdsOnDay,
    AdHocVisitEffect? Function()? effect,
    bool? hidden,
  }) =>
      AdHocVisitState(
        status: status ?? this.status,
        pending: pending ?? this.pending,
        depotIdsOnDay: depotIdsOnDay ?? this.depotIdsOnDay,
        effect: effect != null ? effect() : this.effect,
        hidden: hidden ?? this.hidden,
      );

  @override
  List<Object?> get props => [status, pending, depotIdsOnDay, effect, hidden];
}

enum AdHocVisitStatus { idle, submitting }

/// A thing the screen should do exactly once.
sealed class AdHocVisitEffect extends Equatable {
  const AdHocVisitEffect();
  @override
  List<Object?> get props => [];
}

/// The visit exists. [stopId] is real and immediately checkable-in to.
final class AdHocVisitCreated extends AdHocVisitEffect {
  const AdHocVisitCreated({required this.stopId, required this.depotName});
  final String stopId;
  final String depotName;
  @override
  List<Object?> get props => [stopId, depotName];
}

/// The depot was already on today. Take the rep to the card they already have
/// rather than showing them an error for something that is already true.
final class AdHocVisitAlreadyThere extends AdHocVisitEffect {
  const AdHocVisitAlreadyThere(
      {required this.depotId, required this.depotName});
  final String depotId;
  final String depotName;
  @override
  List<Object?> get props => [depotId, depotName];
}

/// The request is persisted and will be retried. Not an error.
final class AdHocVisitWaiting extends AdHocVisitEffect {
  const AdHocVisitWaiting({required this.depotName});
  final String depotName;
  @override
  List<Object?> get props => [depotName];
}

/// A business refusal. [message] is already user-safe — either the server's
/// own localised copy or a localisation key this app owns.
final class AdHocVisitRefused extends AdHocVisitEffect {
  const AdHocVisitRefused({required this.message, this.supportReference});
  final String message;

  /// A correlation id to quote to support, when the refusal needs one.
  final String? supportReference;
  @override
  List<Object?> get props => [message, supportReference];
}
