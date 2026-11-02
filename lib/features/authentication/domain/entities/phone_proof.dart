import 'package:equatable/equatable.dart';

/// The backend's single-use proof that the signed-in rep controls their
/// account's phone, issued in exchange for Firebase's ID token. It stands in
/// for the current password on the change-password call.
///
/// Held in memory for one change attempt only: never persisted, logged, or
/// put in a bloc state.
class PhoneProof extends Equatable {
  const PhoneProof({
    required this.token,
    required this.issuedAt,
    this.expiresIn = 300,
  });

  final String token;
  final DateTime issuedAt;

  /// Seconds the server keeps [token] valid.
  final int expiresIn;

  /// True once the server would refuse [token] anyway. Checked before the
  /// change call so a stale proof costs no round trip.
  bool isExpiredAt(DateTime now) =>
      !now.isBefore(issuedAt.add(Duration(seconds: expiresIn)));

  // The token is left out on purpose: props end up in test-failure and debug
  // output.
  @override
  List<Object?> get props => [issuedAt, expiresIn];
}
