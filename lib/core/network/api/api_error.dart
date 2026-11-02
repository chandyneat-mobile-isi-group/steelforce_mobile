import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:steelforce/core/network/interceptors/api_headers_interceptor.dart';
import 'package:steelforce/core/network/transport/tls_failure.dart';

/// The stable, machine-readable identity of a server error.
///
/// **The API speaks three error dialects and which one you get depends on the
/// endpoint.** This type is the single place that knows the difference, so no
/// call site has to:
///
///  * `/auth/login`, `/auth/refresh` and `/auth/token` are real OAuth 2.0
///    endpoints and answer `{error, error_description, error_uri}` at HTTP
///    **400** — RFC 6749 §5.2 mandates 400 for a rejected grant, so a wrong
///    password does *not* arrive as 401.
///  * RFC 9457 problem documents carry `errorCode`, `title`, `detail` and a
///    `correlationId`.
///  * The wrapped envelope — what `/mobile/auth/login` actually answers on
///    staging — nests everything: `{success: false, error: {code, message,
///    traceId, details}}`, with SCREAMING_SNAKE codes (`AUTH_INVALID_CREDENTIALS`).
///
/// [code] is normalised across both — `Auth.InvalidCredentials` reads the same
/// whether it arrived as an `error_uri` path segment or an `errorCode` field.
/// **Branch on [code], never on [detail] or on a status code alone.**
class ApiError extends Equatable {
  const ApiError({
    required this.code,
    this.message,
    this.detail,
    this.statusCode,
    this.fieldErrors = const {},
    this.correlationId,
    this.details,
    this.serverCode,
    this.causeType,
    this.causeMessage,
    this.retryAfter,
  });

  /// Stable platform code, e.g. `Auth.InvalidCredentials`, `Depot.NotFound`,
  /// `General.Validation`. This is what user-facing copy is keyed off, so a
  /// Khmer-speaking user never sees an English string the server wrote.
  final String code;

  /// Server-localised and safe to show, when the endpoint supplies one.
  /// Wrapped responses carry this as `message`; problem documents as `title`.
  final String? message;

  /// English, written for developers. **For logs and bug reports only** —
  /// never put this in a dialog.
  final String? detail;

  final int? statusCode;

  /// Per-field validation messages from a `General.Validation` response,
  /// keyed as the server sends them (e.g. `parameters.modifiedSince`).
  final Map<String, List<String>> fieldErrors;

  /// Quote this in a bug report and support can find the exact request.
  final String? correlationId;

  /// The problem document's `details` object, when the endpoint sends one —
  /// e.g. the server's current visit on a `409 Visit.AlreadyCheckedIn`, so
  /// the client can adopt it instead of retrying.
  final Map<String, dynamic>? details;

  /// The code exactly as the server sent it, when it differs from [code] —
  /// e.g. `AUTH_RESET_CODE_INVALID`, which has no app-side equivalent and so
  /// keeps the status-derived [code]. **For logs only;** branch on [code].
  final String? serverCode;

  /// For a request that got no response: the runtime type of the underlying
  /// error (`HandshakeException`, `SocketException`, …). Without it every
  /// such failure logs as a bare `Client.Unknown`. **For logs only.**
  final String? causeType;

  /// The underlying error's own text, trimmed. Written for developers — it
  /// can name the host or an OS error — so **never shown to the user**.
  final String? causeMessage;

  /// Server-calculated cooldown: the HTTP `Retry-After` header, else the
  /// error's `details.retryAfterSeconds`.
  final Duration? retryAfter;

  /// True when the caller may never perform this action, as opposed to
  /// holding a stale token. **A 403 must not sign the user out** — hide the
  /// action instead. Only [isUnauthenticated] justifies dropping the session.
  bool get isPermissionDenied =>
      statusCode == 403 || code == ApiErrorCodes.permissionDenied;

  bool get isUnauthenticated =>
      statusCode == 401 || code == ApiErrorCodes.notAuthenticated;

  bool get isValidation =>
      code == ApiErrorCodes.validation || fieldErrors.isNotEmpty;

  /// The first message for [field], for binding straight to a form field.
  String? fieldError(String field) {
    for (final entry in fieldErrors.entries) {
      // The server prefixes query-parameter fields (`parameters.modifiedSince`)
      // and body fields are sometimes camelCased differently per endpoint, so
      // match on the trailing segment rather than demanding an exact key.
      if (entry.key == field || entry.key.endsWith('.$field')) {
        return entry.value.isEmpty ? null : entry.value.first;
      }
    }
    return null;
  }

  // ── Parsing ────────────────────────────────────────────────────────

  /// Reads whichever dialect [body] is written in.
  factory ApiError.fromBody(Object? body, {int? statusCode}) {
    if (body is! Map) {
      return ApiError(code: ApiErrorCodes.unknown, statusCode: statusCode);
    }
    final map = body.cast<String, dynamic>();

    // OAuth 2.0 shape. `error` is a bare token like `invalid_grant`; the
    // stable platform code is the last path segment of `error_uri`, which is
    // what the docs table lists and what survives an OAuth token being
    // reused for a different condition.
    if (map['error'] is String) {
      return ApiError(
        code: _codeFromUri(map['error_uri']) ?? map['error'] as String,
        message: map['error_description'] as String?,
        detail: map['error_description'] as String?,
        statusCode: statusCode,
      );
    }

    // Wrapped envelope: `{success: false, error: {code, message, traceId}}`.
    //
    // Only codes with an exact app-side meaning are translated; every other
    // code keeps the status-derived one, because call sites already branch on
    // those (`General.Validation` for a 400, for one) and a raw server code
    // they have never heard of would silently drop them into a default arm.
    final nested = map['error'];
    if (nested is Map) {
      final error = nested.cast<String, dynamic>();
      final raw = error['code'] as String?;
      return ApiError(
        code: _wrappedCodes[raw] ?? _codeFromStatus(statusCode),
        message: error['message'] as String?,
        statusCode: statusCode,
        fieldErrors: _fieldErrors(error['errors']),
        correlationId: (error['traceId'] ??
            error['correlationId'] ??
            map['traceId']) as String?,
        details: error['details'] is Map
            ? (error['details'] as Map).cast<String, dynamic>()
            : null,
        serverCode: raw,
      );
    }

    // RFC 9457 problem document.
    final status = (map['status'] as num?)?.toInt() ?? statusCode;
    final errorCode = map['errorCode'] as String? ??
        _codeFromUri(map['type']) ??
        _codeFromStatus(status);
    return ApiError(
      code: errorCode,
      // A wrapped failure response uses `message`; a problem document uses
      // `title`. Both are server-localised.
      message: (map['message'] ?? map['title']) as String?,
      detail: map['detail'] as String?,
      statusCode: status,
      fieldErrors: _fieldErrors(map['errors']),
      correlationId: (map['correlationId'] ?? map['traceId']) as String?,
      details: map['details'] is Map
          ? (map['details'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  /// Normalises any Dio failure — including a transport failure that never
  /// reached the server — into an [ApiError].
  ///
  /// Two things are carried through that used to be dropped:
  ///
  ///  * **The cause.** A request with no response keeps the underlying
  ///    error's type and text ([causeType], [causeMessage]), so a TLS failure,
  ///    a dropped connection and a client-side bug stop all logging as the
  ///    same `Client.Unknown`.
  ///  * **The correlation id.** The server's own id when it answered, else the
  ///    one this app sent in `X-Correlation-Id` — the id support can search
  ///    for even when the request never got a reply.
  factory ApiError.fromDio(DioException e) {
    final sentId =
        e.requestOptions.headers[ApiHeadersInterceptor.correlationHeader];
    final requestId = sentId is String ? sentId : null;
    final cause = e.response == null ? e.error : null;
    final causeType = cause?.runtimeType.toString();
    final causeMessage = cause == null ? null : _trim(cause.toString());

    final offline = switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
    if (offline) {
      return ApiError(
        code: ApiErrorCodes.network,
        correlationId: requestId,
        causeType: causeType,
        causeMessage: causeMessage,
      );
    }

    // No response, and the handshake is what failed. Kept apart from
    // [ApiErrorCodes.network] on purpose: callers that queue and retry on
    // `network` should not start retrying a failure a retry cannot fix.
    if (e.response == null &&
        (e.type == DioExceptionType.badCertificate || isTlsFailure(cause))) {
      return ApiError(
        code: ApiErrorCodes.secureConnection,
        correlationId: requestId,
        causeType: causeType,
        causeMessage: causeMessage,
      );
    }

    final parsed =
        ApiError.fromBody(e.response?.data, statusCode: e.response?.statusCode);
    return ApiError(
      code: parsed.code,
      message: parsed.message,
      detail: parsed.detail,
      statusCode: parsed.statusCode,
      fieldErrors: parsed.fieldErrors,
      correlationId: parsed.correlationId ?? requestId,
      details: parsed.details,
      serverCode: parsed.serverCode,
      causeType: causeType,
      causeMessage: causeMessage,
      // The header is authoritative; the body's `retryAfterSeconds` covers a
      // proxy that strips it.
      retryAfter: _retryAfter(e.response?.headers.value('retry-after')) ??
          _retryAfter('${parsed.details?['retryAfterSeconds'] ?? ''}'),
    );
  }

  /// Wrapped-envelope codes with an exact app-side equivalent. Taken from the
  /// backend's `IdentityErrors.cs`; anything not listed keeps the
  /// status-derived code (see [ApiError.fromBody]).
  static const _wrappedCodes = {
    'AUTH_INVALID_CREDENTIALS': ApiErrorCodes.invalidCredentials,
    'AUTH_ACCOUNT_LOCKED': ApiErrorCodes.accountLocked,
    'AUTH_ACCOUNT_DISABLED': ApiErrorCodes.accountInactive,
    'AUTH_UNAUTHENTICATED': ApiErrorCodes.notAuthenticated,
    'AUTH_FORBIDDEN': ApiErrorCodes.permissionDenied,
  };

  static String _trim(String text) =>
      text.length <= 300 ? text : '${text.substring(0, 300)}…';

  /// `https://docs.isigroup.com.kh/errors/Auth.InvalidCredentials`
  /// → `Auth.InvalidCredentials`.
  ///
  /// Only platform error URLs are mined. Framework-generated problem documents
  /// point `type` at the RFC itself — ASP.NET answers a bare 403 with
  /// `https://tools.ietf.org/html/rfc9110#section-15.5.4` — and taking the last
  /// path segment of that yields `rfc9110#section-15.5.4`, a "code" that means
  /// nothing, matches no branch, and is actively misleading in a log.
  static String? _codeFromUri(Object? uri) {
    if (uri is! String || uri.isEmpty) return null;

    // The platform's own errors live under a `/errors/<Code>` path. Anything
    // else is a spec reference, not an identifier.
    final match = RegExp(r'/errors/([^/#?]+)').firstMatch(uri);
    return match?.group(1);
  }

  /// Last resort when the server sent no `errorCode` and no platform error
  /// URL: derive something stable and branchable from the status alone, so a
  /// framework-generated document still routes correctly.
  static String _codeFromStatus(int? status) => switch (status) {
        401 => ApiErrorCodes.notAuthenticated,
        403 => ApiErrorCodes.permissionDenied,
        429 => ApiErrorCodes.tooManyRequests,
        400 || 422 => ApiErrorCodes.validation,
        _ => ApiErrorCodes.unknown,
      };

  static Map<String, List<String>> _fieldErrors(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): switch (entry.value) {
          final List<dynamic> list => list.map((e) => '$e').toList(),
          final Object v => ['$v'],
          null => const <String>[],
        },
    };
  }

  @override
  List<Object?> get props =>
      [code, message, statusCode, fieldErrors, retryAfter];

  @override
  String toString() => 'ApiError($code, status: $statusCode, '
      'correlationId: $correlationId)';
}

Duration? _retryAfter(String? value) {
  final seconds = int.tryParse(value ?? '');
  return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
}

/// Thrown by data sources; repositories translate it into a `Failure`.
class ApiException implements Exception {
  const ApiException(this.error);
  final ApiError error;

  String get code => error.code;
  int? get statusCode => error.statusCode;

  @override
  String toString() => 'ApiException(${error.code})';
}

/// The codes worth handling by name. Anything absent here should fall through
/// to a generic message rather than being special-cased at a call site.
abstract final class ApiErrorCodes {
  // ── Auth ─────────────────────────────────────────────────────────
  /// Show "ID or password incorrect". **Never say which was wrong.**
  static const invalidCredentials = 'Auth.InvalidCredentials';

  /// Show the wait period. Do not retry automatically — the account locks
  /// for 15 minutes after 5 failed attempts, and three background retries
  /// spend three of them.
  static const accountLocked = 'Auth.AccountLocked';

  /// Direct the user to their administrator.
  static const accountInactive = 'Auth.AccountInactive';

  /// Route straight to the change-password screen.
  static const passwordExpired = 'Auth.PasswordExpired';

  /// Refresh once, then sign out.
  static const notAuthenticated = 'Auth.NotAuthenticated';

  /// Hide the action. **Do not sign out.**
  static const permissionDenied = 'Auth.PermissionDenied';

  // ── Phone sign-in with OTP ───────────────────────────────────────
  /// Wrong code. Clear the boxes and let them retry.
  static const invalidVerificationCode = 'Auth.InvalidVerificationCode';

  /// The window closed. Offer "Resend code", not "Try again".
  static const verificationExpired = 'Auth.VerificationExpired';

  /// Five wrong codes. The attempt is **dead** — the correct code will not
  /// rescue it. Return to step 1 and do not offer a resend.
  static const verificationBlocked = 'Auth.VerificationBlocked';

  /// A client bug: `login` was called before `verify-otp` succeeded.
  static const verificationNotCompleted = 'Auth.VerificationNotCompleted';

  /// The attempt is gone or its id was already spent. Restart from step 1.
  static const verificationNotFound = 'Auth.VerificationNotFound';

  /// The send budget (5 per attempt, including the original) is gone.
  static const resendLimitReached = 'Auth.ResendLimitReached';

  // ── General ──────────────────────────────────────────────────────
  /// Back off and honour `Retry-After`.
  static const tooManyRequests = 'General.TooManyRequests';

  /// Read the per-field `errors` map. This is the default path for bad
  /// input: request validation runs before the domain sees the payload, so
  /// several specific codes below only appear when validation is bypassed.
  static const validation = 'General.Validation';

  // ── Depot ─────────────────────────────────────────────────────
  /// Absent, deleted, **or outside your row-level scope**. Present it as
  /// "not there", never as "access denied" — the API deliberately refuses to
  /// distinguish the two so it cannot be used to probe for existence.
  static const depotNotFound = 'Depot.NotFound';
  static const depotDuplicateCode = 'Depot.DuplicateCode';

  /// `(0,0)` was sent — the GPS fix failed. Carries a message written for the
  /// user directly, so show `message` here.
  static const depotCoordinatesMissing = 'Depot.CoordinatesMissing';
  static const depotCoordinatesOutOfRange = 'Depot.CoordinatesOutOfRange';

  /// The depot is closed and immutable (422).
  static const depotClosed = 'Depot.Closed';
  static const depotTooManyContacts = 'Depot.TooManyContacts';

  // ── Ad hoc visits (docs/feature/my-visits/ad-hoc-visits-mobile.md §8) ──
  //
  // Branch on these, never on the status code: two of them share 409 and two
  // share 403, and they call for opposite handling.
  /// 409 — the depot is already on today's **Call Plan**. Not a failure from
  /// the rep's point of view: take them to the stop they already have.
  static const visitDepotAlreadyPlanned = 'Visit.DepotAlreadyPlanned';

  /// 409 — they already added it themselves today. Same handling as
  /// [visitDepotAlreadyPlanned].
  static const visitAdHocAlreadyExists = 'Visit.AdHocAlreadyExists';

  /// 404 — no such depot, **or** not theirs. The two are deliberately
  /// conflated so the endpoint cannot be used to probe ids, so never phrase
  /// this as "does not exist".
  static const visitDepotNotFound = 'Visit.DepotNotFound';

  /// 409 — two depots share that SAP code. Master data needs fixing; nothing
  /// the rep can do, so surface the correlation id for support.
  static const visitDepotCodeAmbiguous = 'Visit.DepotCodeAmbiguous';

  /// 403 — theirs, but suspended and not trading.
  static const visitDepotNotAccessible = 'Visit.DepotNotAccessible';

  /// 400 — a `visitDate` was sent. A client bug; it should never be sent.
  static const visitAdHocDateInvalid = 'Visit.AdHocDateInvalid';

  /// 403 — signed in, but not a field rep. Hide the action for this account.
  /// **This must not sign the user out.**
  static const visitRepNotAuthorized = 'Visit.RepNotAuthorized';

  /// 422 — no territory on their profile; an administrator has to set it.
  static const visitTerritoryNotAssigned = 'Visit.TerritoryNotAssigned';

  /// 422 — the day is at its 100-stop limit.
  static const visitAdHocNotAllowed = 'Visit.AdHocNotAllowed';

  // ── Profile (`PUT /users/me/profile`) ────────────────────────────
  /// Nothing was sent to change.
  static const profileUpdateEmpty = 'User.ProfileUpdateEmpty';

  /// Not a JPG, JPEG, PNG or WEBP.
  static const avatarExtensionNotAllowed = 'User.AvatarExtensionNotAllowed';

  /// The declared type and the file name disagree.
  static const avatarContentTypeMismatch = 'User.AvatarContentTypeMismatch';

  /// Over 2 MB.
  static const avatarTooLarge = 'User.AvatarTooLarge';

  /// A file and `removeAvatar=true` together.
  static const avatarUploadAndRemovalConflict =
      'User.AvatarUploadAndRemovalConflict';

  /// 500 — the image could not be written. Safe to retry.
  static const avatarStorageFailed = 'User.AvatarStorageFailed';

  // ── Client-side sentinels ────────────────────────────────────────
  /// The request never reached the server.
  static const network = 'Client.Network';

  /// No response because the TLS handshake failed — a network answering for
  /// the API host (a FortiGate DNS filter's block page, on 2026-10-19), a
  /// TLS-intercepting proxy or antivirus, or a wrong clock. Not retried like
  /// [network]: a retry on the same network fails the same way.
  static const secureConnection = 'Client.SecureConnection';
  static const unknown = 'Client.Unknown';
}

/// Reads the `Retry-After` header on a 429.
///
/// Exceeding a rate limit must be backed off, not busy-retried. The general
/// limit is a token bucket rather than a fixed window precisely so field staff
/// can burst when a connection returns — hammering it is what turns a
/// recoverable reconnect into a sustained 429.
extension RetryAfter on Response<dynamic> {
  Duration? get retryAfter {
    final raw = headers.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
