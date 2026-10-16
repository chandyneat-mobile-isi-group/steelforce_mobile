import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_token.dart';

/// The OAuth 2.0 token response from `/auth/login`, `/auth/refresh` and
/// `/auth/token`.
///
/// **These three endpoints are not wrapped.** They return the raw RFC 6749
/// §5.1 token response — snake_case field names, no `data` envelope, no user
/// object — because they are served by OpenIddict as a real OAuth token
/// endpoint rather than by a bespoke JSON API. `/auth/me` and every business
/// endpoint *are* wrapped. Do not write one deserialiser for both.
///
/// The profile is fetched separately from `/auth/me`; nothing about the user
/// arrives here.
class AuthTokenModel extends AuthToken {
  const AuthTokenModel({
    required super.accessToken,
    required super.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.passwordChangeRequired = false,
  });

  final String tokenType;

  /// Access-token lifetime in seconds — 899, i.e. 15 minutes.
  ///
  /// Recorded for diagnostics only. **Do not schedule a refresh off it.**
  /// Refresh reactively on 401: a timer keeps waking a phone asleep in a
  /// pocket and drifts against the server clock.
  final int? expiresIn;

  /// True when the account was signed in with a temporary password. The rep
  /// must set their own through `POST /mobile/auth/change-password` before
  /// using the app. Only the mobile login route sends it; absent means false.
  final bool passwordChangeRequired;

  /// Reads the raw OAuth response.
  ///
  /// [id_token] is deliberately ignored. It is an OIDC identity token that
  /// carries none of the territory, depot or feature-flag data the app needs,
  /// all of which comes from `/auth/me`.
  ///
  /// `/api/v1/mobile/auth/login` answers differently: wrapped in the standard
  /// `{data: …}` envelope, with camelCase keys and a `passwordChangeRequired`
  /// flag. Both shapes are read here so either route yields a usable token.
  factory AuthTokenModel.fromMap(DataMap map) {
    final body = map['data'] is Map ? DataMap.from(map['data'] as Map) : map;
    return AuthTokenModel(
      accessToken:
          (body['access_token'] ?? body['accessToken']) as String? ?? '',
      refreshToken:
          (body['refresh_token'] ?? body['refreshToken']) as String? ?? '',
      tokenType:
          (body['token_type'] ?? body['tokenType']) as String? ?? 'Bearer',
      expiresIn: ((body['expires_in'] ?? body['expiresIn']) as num?)?.toInt(),
      passwordChangeRequired: body['passwordChangeRequired'] == true,
    );
  }

  bool get isUsable => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  DataMap toMap() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        if (expiresIn != null) 'expires_in': expiresIn,
      };
}
