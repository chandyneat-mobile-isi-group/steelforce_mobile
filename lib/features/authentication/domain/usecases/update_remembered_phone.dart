import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/repositories/sign_in_memory.dart';

/// Applies the "Remember me" choice after a successful sign-in: keeps the
/// phone number when [phone] is given, forgets any kept number when it is
/// null — so unticking the box on one sign-in clears it for the next.
class UpdateRememberedPhone extends UseCase<void, String?> {
  const UpdateRememberedPhone(this._memory);
  final SignInMemory _memory;

  @override
  ResultFuture<void> call(String? phone) async {
    try {
      if (phone == null || phone.isEmpty) {
        await _memory.forgetPhone();
      } else {
        await _memory.rememberPhone(phone);
      }
      return const Success(null);
    } catch (_) {
      return const Failed(
          CacheFailure(message: 'Could not update the remembered phone.'));
    }
  }
}
