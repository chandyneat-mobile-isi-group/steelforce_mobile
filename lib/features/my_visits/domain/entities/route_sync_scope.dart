import 'package:equatable/equatable.dart';
import 'package:steelforce/core/session/session_manager.dart';

/// Narrows a route pull to the signed-in rep's own work.
///
/// **Neither field authorises anything.** The server derives the rep from the
/// bearer token and must refuse another rep's routes regardless of what the
/// client sends, so [repId] never goes on the wire at all — it exists for
/// local scoping — and [territory] travels only as a filter.
class RouteSyncScope extends Equatable {
  const RouteSyncScope({required this.repId, required this.territory});

  final String repId;

  /// The rep's assigned territory code, e.g. `PP-NORTH`.
  final String territory;

  /// Reads both from the live session.
  ///
  /// [territory] comes from `AuthProfile.territoryCode` via [SessionManager].
  /// It used to be the hardcoded literal `'Phnom Penh'`, from back when the
  /// route feed was a bundled fixture that only ever carried that one value.
  /// Against the real API that string is simply wrong — a rep assigned to
  /// `PP-NORTH` asked for a territory that does not exist and got an empty
  /// day, which is indistinguishable from having no visits scheduled.
  ///
  /// When the profile carries no territory the scope is [unscoped] rather than
  /// a guess: an empty filter lets the server decide from the token alone,
  /// whereas inventing a plausible-looking code quietly returns the wrong
  /// rep's rows or none at all.
  factory RouteSyncScope.forCurrentUser(SessionManager sessionManager) {
    final territory = sessionManager.territoryCode?.trim() ?? '';
    return RouteSyncScope(
      repId: sessionManager.currentUser?.id ?? 'guest',
      territory: territory.isEmpty ? unscoped : territory,
    );
  }

  /// Sentinel for "the profile named no territory".
  ///
  /// Empty rather than a placeholder so it can be omitted from the query
  /// instead of being sent as a literal the server would try to match.
  static const String unscoped = '';

  bool get hasTerritory => territory.isNotEmpty;

  @override
  List<Object?> get props => [repId, territory];
}
