import 'package:steelforce/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

/// Registered so `any()` can stand in for an [AuthProfileModel] argument.
void registerProfileFallbacks() {
  registerFallbackValue(
    AuthProfileModel.fromJson(const {'userId': 'fallback'}),
  );
}
