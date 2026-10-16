# Authentication — Mobile Integration Guide

How the Flutter application signs in, stays signed in, and signs out.

Base URL `https://<host>/api/v1` · All examples verified against the running API.

---

## Contents

1. [Quick start](#quick-start)
2. [Endpoints](#endpoints)
3. [Sign in](#sign-in)
4. [Phone sign-in with OTP — sales reps](#phone-sign-in-with-otp--sales-reps)
5. [The token pair](#the-token-pair)
6. [Refreshing](#refreshing)
7. [Two error formats — read this](#two-error-formats--read-this)
8. [Sessions and devices](#sessions-and-devices)
9. [Password management](#password-management)
10. [Rate limits and lockout](#rate-limits-and-lockout)
11. [Reference client](#reference-client)
12. [Checklist](#checklist)

---

## Quick start

The sales app signs in with **phone + password + OTP** — three requests, see
[Phone sign-in](#phone-sign-in-with-otp--sales-reps):

```dart
// 1. Phone + password. Returns a verificationId; the password is never sent again.
final challenge = await api.sendOtp(phoneNumber: '012345201', password: '…');

// 2. User enters the code. No token yet.
await api.verifyOtp(challenge.verificationId, otp);

// 3. Exchange the verified attempt for the token pair.
final tokens = await api.phoneLogin(challenge.verificationId);
```

The admin portal and back office use employee ID / e-mail instead — one request,
see [Sign in](#sign-in). **Both produce the same token pair**, so everything below
this point is identical for the two:

```dart
// Store the pair in secure storage — never SharedPreferences
await storage.write(key: 'access_token',  value: tokens.accessToken);
await storage.write(key: 'refresh_token', value: tokens.refreshToken);

// Attach to every request
headers['Authorization'] = 'Bearer ${tokens.accessToken}';

// On 401, refresh once and retry
```

Access tokens last **15 minutes**. Refresh tokens last **14 days** and rotate on
every use. Build the refresh-and-retry interceptor before you build any screen —
retrofitting it later means touching every call site.

---

## Endpoints

| Method | Route | Auth | Purpose |
|---|---|---|---|
| `POST` | `/mobile/auth/send-otp` | — | **Phone sign-in step 1** — phone + password, returns a `verificationId` |
| `POST` | `/mobile/auth/verify-otp` | — | **Step 2** — confirm the code. Issues no token |
| `POST` | `/mobile/auth/login` | — | **Step 3** — exchange the `verificationId` for a token pair |
| `POST` | `/mobile/auth/resend-otp` | — | Send another code for an attempt in flight |
| `POST` | `/auth/login` | — | Sign in with employee ID / e-mail, returns a token pair |
| `POST` | `/auth/refresh` | — | Exchange a refresh token for a new pair |
| `POST` | `/auth/token` | — | OAuth 2.0 password grant (standards clients) |
| `POST` | `/auth/logout` | Bearer | End this session, or all of them |
| `GET` | `/auth/me` | Bearer | The signed-in employee's profile |
| `GET` | `/auth/sessions` | Bearer | List active device sessions |
| `DELETE` | `/auth/sessions/{sessionId}` | Bearer | Revoke one session |
| `POST` | `/auth/change-password` | Bearer | Change a known password |
| `POST` | `/auth/forgot-password` | — | Request a reset e-mail |
| `POST` | `/auth/reset-password` | — | Complete a reset |
| `POST` | `/auth/verify-email` | — | Confirm an address |
| `POST` | `/auth/resend-verification` | — | Re-send the confirmation |

---

## Sign in

`POST /api/v1/auth/login`

```json
{
  "employeeId": "EMP000201",
  "password": "…",
  "device": {
    "deviceId": "a3f1c9e0-…",
    "deviceName": "Pixel 8 - Sales",
    "platform": "Android",
    "osVersion": "Android 15",
    "appVersion": "1.4.2+310",
    "timeZone": "Asia/Phnom_Penh",
    "language": "km-KH",
    "pushToken": "fcm-token-…",
    "rememberDevice": true
  }
}
```

**`employeeId` also accepts an e-mail address.** Field representatives know their
personnel number — it is on their badge and payslip — and often have no company
e-mail. Portal users keep signing in with theirs. The server resolves whichever
arrives, so the login form needs one field, labelled "Employee ID or e-mail".

**`device` is optional but send it.** The user types none of it; read it from
`device_info_plus` and `package_info_plus`. It is what turns the session list from
a column of GUIDs into something a representative can act on when they lose a
handset, and it is already attached to the session record when someone reports
"the app crashed this morning".

`deviceId` must survive app restarts. It may change on reinstall — it identifies
an installation, not a person, and is **never** used for authorisation.

### Response — 200

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs…",
  "token_type": "Bearer",
  "expires_in": 899,
  "id_token": "eyJhbGciOiJSUzI1NiIs…",
  "refresh_token": "eyJhbGciOiJSU0EtT0FFUC…"
}
```

> **Not wrapped.** This endpoint returns the raw OAuth 2.0 token response — no
> `data` envelope. `/auth/me` and every business endpoint *are* wrapped. Do not
> write one deserialiser for both.

Field names are the snake_case ones from RFC 6749 §5.1, because this is a real
OAuth 2.0 token endpoint served by OpenIddict rather than a bespoke JSON API.
`flutter_appauth` and generated OpenAPI clients work against it unmodified.

`id_token` is an OIDC identity token. The mobile app does not need it — read the
profile from `/auth/me` instead, which returns territory, depot and feature flags
the `id_token` does not carry.

---

## Phone sign-in with OTP — sales reps

The field sales app signs in with a **phone number and password, confirmed by a
one-time code**. Three requests, in order.

```
  phone + password                    ┌────────────────┐
         │                            │ NOT SIGNED IN  │
         ▼                            └───────┬────────┘
  POST /mobile/auth/send-otp                  │
         │  password checked here             ▼
         │  ─────────────────────►    ┌────────────────┐
         └──── verificationId ────►   │   OTP SENT     │
                                      └───────┬────────┘
  verificationId + otp                        │
         │                                    ▼
  POST /mobile/auth/verify-otp        ┌────────────────┐
         │  204, no token             │  OTP VERIFIED  │
         └──────────────────────►     └───────┬────────┘
                                              │
  verificationId only                         ▼
         │                            ┌────────────────┐
  POST /mobile/auth/login             │ AUTHENTICATED  │
         └──── access + refresh ──►   │ access+refresh │
                                      └────────────────┘
```

**The password is sent once, at step 1.** Everything afterwards presents the
`verificationId`, which is opaque, single-use and expires with the code. Do not
hold the password in memory past step 1, and never re-send it at step 3 — the
endpoint does not accept it.

### Step 1 — `POST /api/v1/mobile/auth/send-otp`

```json
{
  "phoneNumber": "012345201",
  "password": "…",
  "deviceId": "a3f1c9e0-…",
  "deviceName": "Pixel 8 - Sales"
}
```

**Phone numbers are matched on their digits.** `012345201`, `012 345 201`,
`012-345-201` and `+855 12 345 201` all resolve to the same account — all four are
verified. Do not force a format on the user, and do not strip anything client-side.

`deviceId` / `deviceName` are optional but carried through to the session opened at
step 3, so send them here rather than at login.

#### Response — 200 (wrapped)

```json
{
  "data": {
    "verificationId": "019ffa68-ff2a-78f1-98ad-b356bc325fb6",
    "expiresIn": 300,
    "otpLength": 6,
    "mockOtp": "123456"
  },
  "meta": { "correlationId": "0HNNP3E0H3JQF:00000001", "timestamp": "…" }
}
```

Use `otpLength` to size the code boxes and `expiresIn` (seconds) to drive the
countdown. Do not hard-code 6 and 300 — both come from server configuration and
will change when a real SMS provider is wired up.

> **`mockOtp` is temporary scaffolding.** No SMS provider is connected yet, so the
> server runs a mock that accepts one fixed code and returns it here so you can
> build against the flow. **It disappears the moment a real provider is enabled** —
> the field will be absent, not empty. Read it defensively (`data['mockOtp']`, null
> when missing), never display it in a shipped build, and never make the code entry
> screen depend on it.

### Step 2 — `POST /api/v1/mobile/auth/verify-otp`

```json
{ "verificationId": "019ffa68-…", "otp": "123456" }
```

Returns **204 No Content**. This step deliberately issues **no token** — it only
moves the attempt to `Verified`. If your client expects credentials here, it is
reading the old design.

**Five wrong codes abandon the attempt.** The fifth returns `403`
`Auth.VerificationBlocked` and the attempt is dead: the correct code will not
rescue it, and the user must start again from step 1. Enforced server-side and
verified — do not rely on a client-side guess counter.

### Step 3 — `POST /api/v1/mobile/auth/login`

```json
{ "verificationId": "019ffa68-…" }
```

Returns the **same raw OAuth token payload** as `/auth/login` — not wrapped, no
`data` envelope:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs…",
  "token_type": "Bearer",
  "expires_in": 899,
  "refresh_token": "eyJhbGciOiJSU0EtT0FFUC…"
}
```

From here everything is identical to password sign-in: same token pair, same
15-minute expiry, same `/auth/refresh`, same session list. There is no separate
refresh path for phone sign-in.

**The `verificationId` is consumed.** A second `login` with the same id returns
`400` — verified, and deliberate, so a captured id cannot mint a second token.

### Resending — `POST /api/v1/mobile/auth/resend-otp`

```json
{ "verificationId": "019ffa68-…" }
```

Takes only the identifier — do **not** ask for the password again. Returns the same
payload as step 1, with a fresh window and the guess counter reset.

**Capped at 5 sends per attempt**, including the original. The fifth resend returns
`403` `Auth.ResendLimitReached`. Gate the "Resend" button behind the `expiresIn`
countdown rather than letting users spend the budget in ten seconds.

### Errors — note the format change mid-flow

This flow crosses both error formats described [below](#two-error-formats--read-this),
because step 3 is an OAuth token endpoint and the first two are not. **One flow, two
parsers.**

| Step | Condition | Status | Format | Code |
|---|---|---|---|---|
| send-otp | wrong password / unknown number | `401` | problem+json | `Auth.InvalidCredentials` |
| send-otp | account deactivated | `403` | problem+json | `Auth.AccountInactive` |
| verify-otp | wrong code | `400` | problem+json | `Auth.InvalidVerificationCode` |
| verify-otp | 5 wrong codes | `403` | problem+json | `Auth.VerificationBlocked` |
| verify-otp | window closed | `400` | problem+json | `Auth.VerificationExpired` |
| verify-otp / login | unknown, consumed or stale id | `404` / `400` | problem+json / OAuth | `Auth.VerificationNotFound` |
| resend-otp | send budget spent | `403` | problem+json | `Auth.ResendLimitReached` |
| **login** | code not confirmed yet | `400` | **OAuth** | `Auth.VerificationNotCompleted` |
| **login** | id already used | `400` | **OAuth** | `Auth.VerificationNotFound` |

Steps 1, 2 and 4 answer as problem documents:

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Auth.InvalidVerificationCode",
  "status": 400,
  "detail": "The verification code is incorrect.",
  "errorCode": "Auth.InvalidVerificationCode",
  "correlationId": "0HNNP3HSBGIBQ:00000001"
}
```

Step 3 answers in OAuth's shape, where the platform code is the last segment of
`error_uri`:

```json
{
  "error": "invalid_grant",
  "error_description": "The verification code has not been confirmed for this sign-in attempt.",
  "error_uri": "https://docs.isigroup.com.kh/errors/Auth.VerificationNotCompleted"
}
```

> An unknown number and a wrong password are reported identically, in the same
> time, so the endpoint cannot be used to discover which numbers belong to ISI
> staff. Show one message for both — and note that `detail` still reads "e-mail
> address or password" on this shared error. Localise from `errorCode`, as always,
> and this never reaches a user.

### Which sign-in should the app use?

| | Phone + OTP | Employee ID / e-mail + password |
|---|---|---|
| Route | `/mobile/auth/*` | `/auth/login` |
| Audience | Field sales reps | Admin portal, back office |
| Requires a phone number on the account | Yes | No |

Both produce identical tokens against the same accounts. An account with no
`phoneNumber` on file cannot use the phone flow at all — it resolves to nothing and
returns `Auth.InvalidCredentials`.

---

## The token pair

| | Access token | Refresh token |
|---|---|---|
| Lifetime | 15 minutes (`expires_in: 899`) | 14 days |
| Sent as | `Authorization: Bearer …` | Request body |
| Rotates | No — obtain a new one | **Yes, on every use** |
| Storage | `flutter_secure_storage` | `flutter_secure_storage` |

The access token is a JWT carrying identity, roles and **permission claims**. Decode
it locally to hide buttons a user cannot press — but treat that as cosmetic. The
server re-checks every permission, so a client-side check is a courtesy to the user,
never a security control.

**Refresh tokens are single-use and rotate.** Each refresh invalidates the token you
sent. Two consequences for the client:

- Persist the new refresh token **before** using the new access token. A crash
  between the two loses the session and forces a re-login.
- Serialise refresh calls behind a mutex. Two screens hitting 401 at once will
  both refresh, the second will present an already-rotated token, and reuse
  detection will treat it as theft and revoke the session.

---

## Refreshing

`POST /api/v1/auth/refresh`

```json
{ "refreshToken": "eyJhbGciOiJSU0EtT0FFUC…", "deviceId": "a3f1c9e0-…" }
```

Returns the same shape as login, with a fresh pair. Send the **same** `deviceId`
supplied at sign-in so the rotation stays attached to the right session.

### When to refresh

Refresh **reactively, on 401** — not on a timer. A timer keeps waking a phone that
is asleep in a pocket, and it drifts against the server clock. React to the
response the server actually gave you.

```
request → 401 → refresh → retry once → still 401 → sign out
```

Retry exactly once. A second 401 after a successful refresh means the problem is
authorisation, not expiry, and retrying again just loops.

### Standards-based alternative

`POST /api/v1/auth/token` is the OAuth 2.0 password grant, form-encoded:

```
grant_type=password
client_id=isi-mobile
username=EMP000201
password=…
scope=openid profile email roles offline_access isi.api
```

`isi-mobile` is a **public client — send no client secret.** A secret shipped inside
a mobile app is not a secret, and the server rejects a public client that presents
one with `invalid_client`. `offline_access` is required or you get no refresh token
and the session dies in 15 minutes.

Use this if you adopt an off-the-shelf OAuth library. Use `/auth/login` if you are
writing the client by hand — it is friendlier and takes the device block.

---

## Two error formats — read this

**This is the single most common integration mistake.** The API returns two
different error shapes, and which one you get depends on the endpoint.

### Auth endpoints → OAuth 2.0 errors

`/auth/login`, `/auth/refresh` and `/auth/token` are OAuth endpoints and answer in
OAuth's format:

```json
{
  "error": "invalid_grant",
  "error_description": "The e-mail address or password is incorrect.",
  "error_uri": "https://docs.isigroup.com.kh/errors/Auth.InvalidCredentials"
}
```

Status is **400**, not 401 — that is what RFC 6749 specifies for a rejected grant.
Branch on `error`; the stable platform code is the last path segment of `error_uri`.

### Everything else → RFC 9457 problem documents

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Depot.NotFound",
  "title": "The requested resource was not found.",
  "status": 404,
  "detail": "No depot was found with identifier '…'.",
  "instance": "/api/v1/mobile/depots/…",
  "errorCode": "Depot.NotFound",
  "correlationId": "0HNNOE4PB87QD:00000001"
}
```

Branch on **`errorCode`**. It is stable and it is what the app localises from, so a
Khmer-speaking user never sees an English string the server wrote. `detail` is for
your logs and your bug reports, not for a dialog.

Validation failures add a per-field `errors` map:

```json
"errors": {
  "parameters.modifiedSince": [
    "modifiedSince cannot be in the future. Send the syncTimestamp from the previous response…"
  ]
}
```

### Codes worth handling by name

| Code | Status | What the app should do |
|---|---|---|
| `Auth.InvalidCredentials` | 400 / 401 | Show "ID or password incorrect". Never say which. |
| `Auth.AccountLocked` | 400 | Show the wait period; do not retry automatically. |
| `Auth.AccountInactive` | 400 / 403 | Direct the user to their administrator. |
| `Auth.PasswordExpired` | 400 | Route straight to the change-password screen. |
| `Auth.NotAuthenticated` | 401 | Refresh once, then sign out. |
| `Auth.PermissionDenied` | 403 | Do **not** sign out. Hide the action. |
| `Auth.InvalidVerificationCode` | 400 | Clear the code boxes, let them retry. Show attempts remaining. |
| `Auth.VerificationExpired` | 400 | Offer "Resend code", not "Try again". |
| `Auth.VerificationBlocked` | 403 | Attempt is dead. Return to step 1; do not offer a resend. |
| `Auth.VerificationNotCompleted` | 400 | Client bug — you called login before verify-otp. |
| `Auth.VerificationNotFound` | 400 / 404 | The attempt is gone or already used. Restart from step 1. |
| `Auth.ResendLimitReached` | 403 | Hide "Resend"; send them back to step 1. |
| `General.TooManyRequests` | 429 | Back off; honour `Retry-After`. |

The status column shows two values where a code is returned from both an OAuth
endpoint and an ordinary one. **Branch on the code, not the status** — that is
precisely why the code exists.

**403 is not 401.** A 403 means this user may never do this — signing them out and
showing a login screen is wrong and confusing. Only 401 means "your token is stale".

---

## Sessions and devices

`GET /api/v1/auth/sessions` returns every active session, wrapped in the standard
envelope:

```json
{
  "data": [{
    "sessionId": "019fefd2-…",
    "deviceId": "a3f1c9e0-…",
    "deviceName": "Pixel 8 - Sales",
    "ipAddress": "203.0.113.9",
    "userAgent": "ISIApp/1.4.2 (Android 15)",
    "createdAt": "2026-08-12T02:14:06Z",
    "lastSeenAt": "2026-08-12T08:41:22Z",
    "expiresAt": "2026-08-26T02:14:06Z",
    "isCurrent": true
  }]
}
```

`DELETE /api/v1/auth/sessions/{sessionId}` revokes one — this is "I lost my phone".
`isCurrent` marks the caller's own session; warn before revoking it, because doing so
signs the user out of the device they are holding.

**A user may hold 5 concurrent sessions.** A sixth sign-in retires the oldest. A
device flagged `rememberDevice: true` is protected from being retired first — a
convenience, not a privilege: it grants nothing and extends no lifetime.

### Signing out

`POST /api/v1/auth/logout` → **204**

```json
{ "refreshToken": "eyJhbGciOiJSU0EtT0FFUC…", "allDevices": false }
```

`allDevices: true` ends every session — offer it after a password change or a
suspected compromise. Clear secure storage **after** the call returns, and clear it
even if the call fails; a token you have discarded locally is unusable regardless.

---

## Password management

| Endpoint | Auth | Notes |
|---|---|---|
| `POST /auth/change-password` | Bearer | `{ currentPassword, newPassword }` |
| `POST /auth/forgot-password` | — | `{ email }` |
| `POST /auth/reset-password` | — | `{ email, token, newPassword }` |
| `POST /auth/verify-email` | — | `{ userId, token }` |
| `POST /auth/resend-verification` | — | `{ email }` |

Minimum password length is **12 characters**.

`change-password` re-verifies the current password even though the caller is already
authenticated. That is deliberate: it is what stops a borrowed unlocked handset from
becoming a permanent account takeover.

`forgot-password` always returns success, whether or not the address exists. Do not
"improve" the UX by reporting that an address is unknown — that turns the endpoint
into an account-enumeration oracle. Show "if that address is registered, a link is on
its way".

After a successful change, call `logout` with `allDevices: true`, then sign in again.

---

## Rate limits and lockout

| Scope | Limit |
|---|---|
| Sensitive endpoints (login, password, verification) | **10 per 5 minutes** |
| General API, per caller | 200 burst, refilling 100/minute |
| Global chained ceiling | 300 burst, refilling 150/minute |

Exceeding a limit returns **429** with `errorCode: General.TooManyRequests`. Honour
`Retry-After`; do not busy-retry.

The general limit is a **token bucket, not a fixed window** — deliberately. Field
staff work in bursts when a connection returns, and a fixed window would reject the
whole reconnect burst. Sync freely; just do not hammer.

**Account lockout policy: 5 failed password attempts, 15 minute lock.** Client-side
retry logic must never resend a rejected password automatically — three background
retries spend three of the five attempts and lock a user who typed one wrong
character.

> **Known server-side issue:** this lockout is not currently being enforced —
> failed attempts are not persisting, so accounts do not lock. Build the client as
> if it works, because it will: the policy above is the contract, and the fix does
> not change it. Do not design around the gap, and do not use it to justify
> automatic retries.

**OTP attempts are capped and this cap *is* enforced.** Five wrong codes against one
`verificationId` return `403` `Auth.VerificationBlocked` and kill the attempt
permanently. Five sends per attempt, including the original, then
`Auth.ResendLimitReached`. Both are server-side and verified — a client-side counter
is a UX nicety, not the control.

---

## Reference client

A minimal Dio setup covering the whole contract. Adapt, don't copy blindly.

```dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  // One refresh at a time. Without this, parallel 401s each rotate the token and
  // all but the first present a token the server has already retired.
  Future<void>? _refreshing;

  @override
  Future<void> onRequest(options, handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) options.headers['Authorization'] = 'Bearer $token';

    // Server-side localisation: shopName, statusDisplay and every message come
    // back already translated.
    options.headers['Accept-Language'] = Intl.getCurrentLocale();

    // Traceable end to end. Quote this id in a bug report and support can find
    // the exact request in the logs.
    options.headers['X-Correlation-Id'] = const Uuid().v4();

    handler.next(options);
  }

  @override
  Future<void> onError(DioException e, handler) async {
    if (e.response?.statusCode != 401 || _isRetry(e.requestOptions)) {
      return handler.next(e);
    }

    try {
      await (_refreshing ??= _refresh());
    } catch (_) {
      await signOut();
      return handler.next(e);
    } finally {
      _refreshing = null;
    }

    final opts = e.requestOptions..extra['retried'] = true;
    handler.resolve(await _dio.fetch(opts));
  }

  bool _isRetry(RequestOptions o) => o.extra['retried'] == true;

  Future<void> _refresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) throw StateError('no refresh token');

    final res = await Dio().post(
      '$baseUrl/auth/refresh',
      data: {'refreshToken': refreshToken, 'deviceId': await deviceId()},
    );

    // Persist the refresh token FIRST. A crash after using the new access token
    // but before storing the new refresh token loses the session.
    await _storage.write(key: 'refresh_token', value: res.data['refresh_token']);
    await _storage.write(key: 'access_token',  value: res.data['access_token']);
  }
}
```

### Phone sign-in

```dart
/// Step 1. The only call that sees the password.
Future<OtpChallenge> sendOtp(String phoneNumber, String password) async {
  final res = await _dio.post('/mobile/auth/send-otp', data: {
    'phoneNumber': phoneNumber,          // as typed - do not reformat
    'password': password,
    'deviceId': await deviceId(),
    'deviceName': await deviceName(),
  });

  final d = res.data['data'];            // wrapped, unlike step 3
  return OtpChallenge(
    verificationId: d['verificationId'],
    expiresIn: d['expiresIn'],           // drive the countdown from this
    otpLength: d['otpLength'],           // size the boxes from this
    // Present only while the server runs the mock provider. Absent once a real
    // SMS gateway is enabled, so read it defensively and never show it shipped.
    mockOtp: d['mockOtp'] as String?,
  );
}

/// Step 2. Returns 204 - no token here.
Future<void> verifyOtp(String verificationId, String otp) =>
    _dio.post('/mobile/auth/verify-otp',
        data: {'verificationId': verificationId, 'otp': otp});

/// Step 3. Same raw OAuth payload as /auth/login - NOT wrapped.
Future<void> phoneLogin(String verificationId) async {
  final res = await _dio.post('/mobile/auth/login',
      data: {'verificationId': verificationId});

  // Refresh token first - see "The token pair" for why the order matters.
  await _storage.write(key: 'refresh_token', value: res.data['refresh_token']);
  await _storage.write(key: 'access_token',  value: res.data['access_token']);
}
```

The `verificationId` is spent once `phoneLogin` succeeds. Hold it only for the
lifetime of the code screen, and start again at step 1 on any failure other than a
plain wrong code.

### Reading permissions from the profile

```dart
final me = await api.get('/auth/me');          // wrapped: { "data": { … } }
final profile = me.data['data'];

final permissions = Set<String>.from(profile['permissions']);
final canCreate   = permissions.contains('depots.create');

// Absent flags mean off, so a client built against a newer server degrades
// instead of throwing.
final flags = Map<String, bool>.from(profile['featureFlags'] ?? {});
```

`/auth/me` also returns `territoryCode`, `depotCode`, `language`, `timeZone`,
`theme` and `passwordExpiresAt`. Read the user's language from here on first launch
rather than assuming the device locale.

---

## Checklist

Before you ship:

- [ ] Tokens in `flutter_secure_storage`, never `SharedPreferences`
- [ ] Refresh is reactive on 401, never on a timer
- [ ] Refresh is serialised behind a single mutex
- [ ] New refresh token persisted before the new access token is used
- [ ] Retry after refresh happens **once**
- [ ] 403 hides the action; only 401 signs the user out
- [ ] Auth errors parsed as `{error, error_description}`, others as `problem+json`
- [ ] `send-otp` / `verify-otp` / `resend-otp` parsed as `problem+json`, but
      `mobile/auth/login` parsed as OAuth — **one flow, two parsers**
- [ ] All user-facing messages keyed off `errorCode`, never off `detail`
- [ ] Password discarded from memory after `send-otp`; never re-sent at login
- [ ] `verificationId` treated as single-use — a new attempt after every login
- [ ] Code length and countdown driven by `otpLength` / `expiresIn`, not hard-coded
- [ ] `mockOtp` never read in a release build, and absent-field safe
- [ ] Phone number sent as the user typed it — no client-side reformatting
- [ ] "Resend" gated behind the countdown; hidden on `Auth.ResendLimitReached`
- [ ] No automatic retry of a rejected password (lockout is 5 attempts)
- [ ] `Accept-Language` sent on every request
- [ ] `X-Correlation-Id` sent on every request
- [ ] Secure storage cleared on logout even when the call fails

---

## See also

- [depots-guidline-integrateion-mobile.md](../depot/api.md) — depot endpoints and offline sync
- `Authentication.md` (⧉ backend repo) — server-side design and reuse detection. Mobile-side: [../../blueprint/authentication-architecture.md](../../blueprint/authentication-architecture.md)
- `/docs` on any running instance — interactive reference, pre-authorised in Development
