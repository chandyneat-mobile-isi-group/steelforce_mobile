import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_proof.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_ownership_reset_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_password_change_repository.dart';
import 'package:steelforce/features/authentication/domain/usecases/phone_password_change.dart';
import 'package:steelforce/features/authentication/presentation/bloc/phone_password_change_state.dart';

/// Drives the signed-in password change: own-number SMS → Firebase code →
/// backend phone proof → new password.
///
/// Lives as long as the flow's route. The phone proof is held here, in
/// memory only, and dropped on success, on any failure that may have spent
/// it, and on [close] — so leaving the screen abandons it.
class PhonePasswordChangeCubit extends Cubit<PhonePasswordChangeState> {
  PhonePasswordChangeCubit({
    required StartOwnPhoneVerification startVerification,
    required VerifyOwnPhoneProof verifyProof,
    required ChangePasswordWithPhoneProof changePassword,
    bool available = true,
    this.policy = PasswordPolicy.productionReset,
    DateTime Function()? now,
  })  : _start = startVerification,
        _verify = verifyProof,
        _change = changePassword,
        _available = available,
        _now = now ?? DateTime.now,
        super(const PhonePasswordChangeStarting());

  final StartOwnPhoneVerification _start;
  final VerifyOwnPhoneProof _verify;
  final ChangePasswordWithPhoneProof _change;

  /// False where Firebase phone auth does not exist (web), so nothing is
  /// started that could never finish.
  final bool _available;
  final DateTime Function() _now;

  /// Checked on the device first; the server has the final say.
  final PasswordPolicy policy;

  PhoneVerificationHandle? _handle;
  PhoneProof? _proof;
  int _attempts = 0;

  /// One request at a time: a double tap must not spend a proof twice.
  bool _busy = false;

  /// Returned while a request is already in flight.
  static const busy =
      ServerFailure(message: 'Busy.', code: 'phone_change.busy');

  /// The session the code screen confirms against. Read once per code.
  PhoneVerificationHandle? get handle => _handle;

  /// For tests: whether a phone proof is still held.
  bool get holdsProof => _proof != null;

  /// Opens a verification and sends the SMS. Also the resend. Null on
  /// success; on a failed resend the code screen shows the failure.
  Future<Failure?> start() async {
    if (_busy) return busy;
    if (!_available) {
      _halt(
        const AuthenticationFailure(
          message: 'Phone verification is unavailable.',
          code: 'phone.unavailable',
        ),
        canRestart: false,
      );
      return null;
    }
    final resend = state is PhonePasswordChangeCodeSent;
    if (!resend) emit(const PhonePasswordChangeStarting());
    _proof = null;
    _busy = true;
    final result = await _start(const NoParams());
    _busy = false;
    if (isClosed) return null;
    return result.when(
      success: (handle) {
        _handle = handle;
        emit(PhonePasswordChangeCodeSent(
          phoneNumber: handle.phoneNumber,
          resendAfter: Duration(seconds: handle.resendAfter),
          attempt: ++_attempts,
          verifiedWithoutCode: handle.isVerified,
        ));
        return null;
      },
      failure: (f) {
        final restartable = _canRestart(f);
        if (!resend || !restartable) _halt(f, canRestart: restartable);
        return f;
      },
    );
  }

  /// Confirms [code] (empty when Android verified the number) and obtains
  /// the phone proof. Null on success.
  Future<Failure?> verifyCode(String code) async {
    final handle = _handle;
    if (_busy || handle == null) return busy;
    _busy = true;
    final result =
        await _verify(VerifyOwnPhoneParams(handle: handle, otp: code));
    _busy = false;
    if (isClosed) return null;
    return result.when(
      success: (proof) {
        _proof = proof;
        emit(PhonePasswordChangeEnteringPassword(policy));
        return null;
      },
      // The code screen keeps the session: a wrong code can be retyped, and a
      // refused proof asks for a new code there.
      failure: (f) => f,
    );
  }

  /// Sets [newPassword] with the held proof. Null on success.
  Future<Failure?> submitNewPassword(String newPassword) async {
    if (_busy) return busy;
    final proof = _proof;
    if (proof == null || proof.isExpiredAt(_now())) {
      // Spent or stale: the server would refuse it, so do not send it.
      const expired = AuthenticationFailure(
        message: 'Verification expired.',
        code: PhonePasswordChangeCodes.proofInvalid,
      );
      _halt(expired, canRestart: true);
      return expired;
    }
    _busy = true;
    final result = await _change(ChangePasswordWithPhoneProofParams(
      proof: proof,
      newPassword: newPassword,
    ));
    _busy = false;
    if (isClosed) return null;
    return result.when(
      success: (_) {
        _proof = null;
        _handle = null;
        emit(const PhonePasswordChangeSucceeded());
        return null;
      },
      failure: (f) {
        if (_proofSurvives(f)) return f;
        _halt(f, canRestart: _canRestart(f));
        return f;
      },
    );
  }

  @override
  Future<void> close() {
    _proof = null;
    _handle = null;
    return super.close();
  }

  void _halt(Failure f, {required bool canRestart}) {
    _proof = null;
    if (!isClosed) emit(PhonePasswordChangeHalted(f, canRestart: canRestart));
  }

  /// Failures after which the server has certainly not spent the proof: the
  /// request never left the device, was rate limited before it was handled,
  /// or the password failed the policy (the server keeps the proof valid).
  static bool _proofSurvives(Failure f) =>
      f is NetworkFailure ||
      (f is ServerFailure && (f.statusCode == 429 || f.statusCode == 400));

  /// A new code cannot fix a missing number, a disabled channel, a forbidden
  /// action or a dead session.
  static bool _canRestart(Failure f) {
    final code = switch (f) {
      AuthenticationFailure(:final code) => code,
      ServerFailure(:final code) => code,
      _ => null,
    };
    if (code == PhonePasswordChangeCodes.phoneNumberRequired ||
        code == PhonePasswordChangeCodes.channelDisabled) {
      return false;
    }
    if (f.statusCode == 403) return false;
    if (f is AuthenticationFailure &&
        code != PhonePasswordChangeCodes.proofInvalid &&
        !(code?.startsWith(phoneFailurePrefix) ?? false)) {
      return false;
    }
    return true;
  }
}
