import 'package:steelforce/core/utils/result.dart';

/// Aliases used across every layer.
///
/// [ResultFuture] is the standard return type of use cases and
/// repository methods — it forces the caller to handle success and
/// failure explicitly at compile time.
typedef ResultFuture<T> = Future<Result<T>>;

/// A decoded JSON object.
typedef DataMap = Map<String, dynamic>;
