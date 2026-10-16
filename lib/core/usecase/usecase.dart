import 'package:equatable/equatable.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// Every use case is a single-responsibility callable object.
abstract class UseCase<T, P> {
  const UseCase();
  ResultFuture<T> call(P params);
}

/// A use case that exposes a continuous [Stream] rather than a one-shot
/// Future — for screens that must react to live local-cache/sync updates
/// (route monitoring, check-in tracking, inventory counts).
abstract class StreamUseCase<T, P> {
  const StreamUseCase();
  Stream<T> call(P params);
}

/// For use cases that take no arguments.
final class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => const [];
}
