import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/repositories/sign_in_memory.dart';

/// The phone number "Remember me" kept from the last sign-in, if any.
class GetRememberedPhone extends UseCase<String?, NoParams> {
  const GetRememberedPhone(this._memory);
  final SignInMemory _memory;

  @override
  ResultFuture<String?> call(NoParams params) async {
    try {
      return Success(await _memory.readPhone());
    } catch (_) {
      return const Failed(
          CacheFailure(message: 'Could not read the remembered phone.'));
    }
  }
}
