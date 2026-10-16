import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_error.dart';

/// `_failure` is private, so these assert the contract through the public
/// helper the presentation layer actually reads.
void main() {
  test('the two 403 verification codes are not permission denials', () {
    // `Auth.VerificationBlocked` and `Auth.ResendLimitReached` arrive as 403.
    // Mapping them by status would hide them behind "you do not have access"
    // and the code screen would never learn the attempt was dead.
    final blocked = ApiError.fromBody(const {
      'errorCode': ApiErrorCodes.verificationBlocked,
      'status': 403,
    });

    expect(blocked.isPermissionDenied, isTrue,
        reason: 'it genuinely is a 403 at the transport level');
    expect(blocked.code, ApiErrorCodes.verificationBlocked,
        reason: 'so the repository must branch on the code, not the status');
  });
}
