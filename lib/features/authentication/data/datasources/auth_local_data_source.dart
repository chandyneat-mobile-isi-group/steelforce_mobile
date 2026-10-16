import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:steelforce/core/database/secure/secure_storage_keys.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/interceptors/auth_interceptor.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/data/models/user_model.dart';

abstract interface class AuthLocalDataSource {
  Future<void> cacheSession({
    required AuthTokenModel token,
    required AuthProfileModel profile,
  });

  /// Persists the token pair alone. Sign-in needs this before it can fetch the
  /// profile, because that call authenticates through the interceptor and so
  /// requires the access token to already be readable.
  ///
  /// Implementations write the refresh token first — see [TokenStore].
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Refreshes the cached profile without touching the token pair — used when
  /// `/auth/me` is re-read on resume.
  Future<void> cacheProfile(AuthProfileModel profile);

  Future<AuthProfileModel?> readProfile();
  Future<UserModel?> readUser();
  Future<AuthTokenModel?> readToken();
  Future<void> clear();
}

/// Backed by encrypted secure storage — never `SharedPreferences`, which is
/// plaintext on disk and readable on a rooted handset.
///
/// Also implements [TokenStore] so the same instance serves the network
/// interceptor: one source of truth for tokens, no duplication and no drift.
class AuthLocalDataSourceImpl implements AuthLocalDataSource, TokenStore {
  const AuthLocalDataSourceImpl(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> cacheSession({
    required AuthTokenModel token,
    required AuthProfileModel profile,
  }) async {
    try {
      await saveTokens(
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
      );
      await _storage.write(
        key: SecureStorageKeys.kCachedUser,
        value: jsonEncode(profile.toJson()),
      );
    } catch (_) {
      throw const CacheException(message: 'Failed to persist session.');
    }
  }

  @override
  Future<void> cacheProfile(AuthProfileModel profile) async {
    try {
      await _storage.write(
        key: SecureStorageKeys.kCachedUser,
        value: jsonEncode(profile.toJson()),
      );
    } catch (_) {
      throw const CacheException(message: 'Failed to persist profile.');
    }
  }

  @override
  Future<AuthProfileModel?> readProfile() async {
    try {
      final raw = await _storage.read(key: SecureStorageKeys.kCachedUser);
      if (raw == null) return null;
      return AuthProfileModel.fromJson(jsonDecode(raw) as DataMap);
    } catch (_) {
      // A cache we cannot decode is a cache we ignore — a schema change
      // between releases must not brick sign-in.
      return null;
    }
  }

  @override
  Future<UserModel?> readUser() async {
    final profile = await readProfile();
    return profile == null ? null : UserModel.fromEntity(profile.toUser());
  }

  @override
  Future<AuthTokenModel?> readToken() async {
    final access = await _storage.read(key: SecureStorageKeys.kAccessToken);
    final refresh = await _storage.read(key: SecureStorageKeys.kRefreshToken);
    if (access == null || refresh == null) return null;
    return AuthTokenModel(accessToken: access, refreshToken: refresh);
  }

  /// Clears the session. The device id deliberately survives: it identifies
  /// the installation, not the person, so the next sign-in should land on the
  /// same session row rather than opening a duplicate.
  @override
  Future<void> clear() => Future.wait([
        _storage.delete(key: SecureStorageKeys.kAccessToken),
        _storage.delete(key: SecureStorageKeys.kRefreshToken),
        _storage.delete(key: SecureStorageKeys.kCachedUser),
      ]);

  // ── TokenStore (consumed by AuthInterceptor) ────────────────────────
  @override
  Future<String?> readAccessToken() =>
      _storage.read(key: SecureStorageKeys.kAccessToken);

  @override
  Future<String?> readRefreshToken() =>
      _storage.read(key: SecureStorageKeys.kRefreshToken);

  /// Writes the refresh token **first**, then the access token — sequentially,
  /// not with `Future.wait`.
  ///
  /// Refresh tokens are single-use and rotate on every use, so the moment the
  /// new access token is in play the old refresh token is already dead. If the
  /// process died between an access-token write and a refresh-token write, the
  /// stored pair would be a live access token beside a retired refresh token:
  /// the session would work for fifteen minutes and then force a re-login.
  /// This ordering makes the worst case a redundant refresh instead.
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
        key: SecureStorageKeys.kRefreshToken, value: refreshToken);
    await _storage.write(
        key: SecureStorageKeys.kAccessToken, value: accessToken);
  }
}
