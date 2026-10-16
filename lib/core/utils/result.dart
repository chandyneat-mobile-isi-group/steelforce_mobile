import 'package:steelforce/core/error/failures.dart';

/// A lightweight, dependency-free functional result type (Dart 3 sealed).
///
/// We return this across architectural boundaries instead of throwing:
/// the exhaustive `switch`/[when] makes it impossible to forget the
/// error branch, and there is zero allocation overhead beyond the wrapper.
sealed class Result<T> {
  const Result();

  /// Fold both branches into a single value.
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) =>
      switch (this) {
        Success<T>(data: final d) => success(d),
        Failed<T>(failure: final f) => failure(f),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);
  final Failure failure;
}
