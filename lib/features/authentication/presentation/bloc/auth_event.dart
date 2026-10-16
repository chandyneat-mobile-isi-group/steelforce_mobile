import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => const [];
}

/// Fired once on app start to resolve any persisted session.
final class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Enter guest browsing explicitly (e.g. after onboarding completes, or when
/// the user dismisses a login prompt with "Later"). Idempotent — safe to fire
/// even if already a guest.
final class AuthGuestRequested extends AuthEvent {
  const AuthGuestRequested();
}

/// Fired by the login form. Name + shape must match LoginScreen.
final class LoginSubmittedEvent extends AuthEvent {
  const LoginSubmittedEvent({
    required this.identifier,
    required this.password,
    this.rememberDevice = true,
    this.rememberPhone = false,
  });

  /// Employee ID **or** e-mail address. The form has one field because the
  /// server accepts either: field reps know their personnel number and often
  /// have no company e-mail, portal users keep using theirs.
  final String identifier;
  final String password;

  /// Protects this device from being retired first once the user exceeds five
  /// concurrent sessions.
  final bool rememberDevice;

  /// "Remember me": on success, keep [identifier] for the next sign-in — or,
  /// when false, forget any number kept before. The password is never kept.
  final bool rememberPhone;

  @override
  List<Object?> get props =>
      [identifier, password, rememberDevice, rememberPhone];
}

final class LogoutRequested extends AuthEvent {
  const LogoutRequested({this.allDevices = false});

  /// Ends every session rather than just this one. Offer it after a password
  /// change or a suspected compromise.
  final bool allDevices;

  @override
  List<Object?> get props => [allDevices];
}

/// The rep replaced their temporary password. Clears the flag on the cached
/// session so the next launch goes to the shell.
final class PasswordChangeCompleted extends AuthEvent {
  const PasswordChangeCompleted();
}
