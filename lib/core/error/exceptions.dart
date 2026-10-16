/// Thrown by data sources. Repositories catch these and translate them
/// into [Failure]s so exceptions never leak past the data layer.
class ServerException implements Exception {
  const ServerException({required this.message, this.statusCode});
  final String message;
  final int? statusCode;
}

class CacheException implements Exception {
  const CacheException({this.message = 'Cache error.'});
  final String message;
}

class NetworkException implements Exception {
  const NetworkException({this.message = 'No internet connection.'});
  final String message;
}

class AuthenticationException implements Exception {
  const AuthenticationException({required this.message, this.statusCode});
  final String message;
  final int? statusCode;
}
