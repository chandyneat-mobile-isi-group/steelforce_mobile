import 'package:equatable/equatable.dart';

/// Domain-level error type. Sealed so presentation code can exhaustively
/// map each variant to a user-facing message if it wants to.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode, this.code});

  final String? code;

  @override
  List<Object?> get props => [message, statusCode, code];
}

final class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection.'});
}

/// The outlet's details are not available to this caller.
///
/// Covers "no such outlet" and "outside your entitlement" **together**, because
/// the server answers both with a bare 404 on purpose: distinguishing them
/// would confirm that a given outlet exists to someone not allowed to know it.
///
/// Its own type rather than a `ServerFailure(statusCode: 404)` so the screen
/// cannot accidentally phrase it as "deleted" — the outlet may well exist.
final class DepotStopInformationUnavailableFailure extends Failure {
  const DepotStopInformationUnavailableFailure({
    super.message = 'These outlet details are not available.',
  }) : super(statusCode: 404);
}

/// An ad hoc visit was refused for a business reason, not a transport one.
///
/// Its own type, carrying [code], because the eight refusals in
/// `docs/feature/my-visits/ad-hoc-visits-mobile.md` §8 need different handling
/// and **cannot be told apart by status**: two share 409 and two share 403.
/// Branching on the status code alone would, among other things, sign a rep out
/// of the app for not being a field rep.
///
/// Note what is *not* here: the two 409s. "Already on today's route" is not a
/// failure from the rep's point of view — it is [AdHocVisitAlreadyOnToday],
/// a success outcome that navigates to the existing stop.
final class AdHocVisitRefusedFailure extends Failure {
  const AdHocVisitRefusedFailure({
    required super.message,
    required this.code,
    super.statusCode,
    this.supportReference,
  });

  /// The stable platform code, e.g. `Visit.AdHocNotAllowed`.
  final String code;

  /// The server's correlation id, set only when the rep has to hand the
  /// problem to support (`Visit.DepotCodeAmbiguous`) — it is how support finds
  /// the server log. Null for every refusal the rep can understand unaided.
  final String? supportReference;

  /// True when the account may never do this, as opposed to this depot being
  /// unavailable. The action should be hidden for the rest of the session
  /// rather than offered again — and the user must **not** be signed out.
  bool get isPermanentlyUnavailable => code == 'Visit.RepNotAuthorized';

  @override
  List<Object?> get props => [message, statusCode, code, supportReference];
}

/// The device has a working network, but the ISI gateway did not answer.
///
/// Deliberately distinct from [NetworkFailure]. Telling a user standing on
/// office WiFi that they have "no internet connection" sends them to check
/// their signal, their router and their data plan — none of which is the
/// problem. The causes here are a wrong `API_BASE_URL`, a backend that is not
/// running, an expired tunnel, or a VPN that is off; every one of them is
/// actionable, and none of them looks like the message the user was given.
final class ServerUnreachableFailure extends Failure {
  const ServerUnreachableFailure({
    super.message = 'Cannot reach the ISI server.',
  });
}

/// Invalid credentials, expired token, or no active session.
final class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    required super.message,
    super.statusCode,
    this.code,
  });

  /// The stable platform code, kept so the presentation layer can tell a
  /// recoverable wrong code from a dead sign-in attempt.
  final String? code;

  @override
  List<Object?> get props => [message, statusCode, code];
}
