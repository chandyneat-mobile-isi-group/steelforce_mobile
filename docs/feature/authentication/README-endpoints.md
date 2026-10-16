# Authentication — Endpoint Summary

> Every backend endpoint the mobile app calls to sign a rep in, keep them
> signed in, recover a password, and show who they are.
>
> Source of truth for the paths: [`lib/core/network/api/api_endpoints.dart`](../../../lib/core/network/api/api_endpoints.dart).
> Checked against the staging OpenAPI spec (`https://www.pnc-spts-stg-api.me/swagger/v1/swagger.json`) on **2026-10-07**.
> Full feature blueprint: [README.md](README.md).

---

## At a glance

| | Count |
|---|---|
| Endpoints the app calls for authentication | **11** |
| ✅ Exist on staging and match | **9** |
| ⚠️ Works, but uses the web route | **1** (logout) |
| ❌ Not on staging yet | **1** (location heartbeat) |

> The old phone + OTP sign-in (`send-otp`, `verify-otp`, `resend-otp`) and the
> session list / revoke calls were **removed on 2026-10-07** — nothing used them
> and staging does not have them.

All paths start with `apiPrefix = /api/v1`. Routes under `/mobile/` need a
signed-in token; the forgot-password routes do **not** sit under `/mobile/`,
because a rep who forgot their password has no token (staging answers `401`
there).

---

## 1. Sign in — 1 endpoint ✅

| Method | Path | Constant | Auth |
|---|---|---|---|
| `POST` | `/api/v1/mobile/auth/login` | `loginEndpoint` | none |

**Request**

```json
{ "phoneNumber": "+85512345209", "password": "••••••", "deviceId": "…", "device": { … } }
```

**Response** — wrapped in `{ "data": … , "success": true }`:

```json
{
  "accessToken": "…", "refreshToken": "…", "tokenType": "Bearer",
  "expiresIn": 899, "passwordChangeRequired": false,
  "user": { … }, "offlineAccess": { … }
}
```

- Tokens come **only** from login and refresh — there is no separate token endpoint.
- `passwordChangeRequired: true` means the rep signed in with a **temporary
  password**. The app sends them to the *Set Your Password* screen (§4) instead
  of the shell, and keeps sending them there after a restart until it is done.

---

## 2. Who is signed in — 2 endpoints ✅

| Method | Path | Constant | Used by |
|---|---|---|---|
| `GET` | `/api/v1/auth/me` | `currentUserEndpoint` | Sign-in (right after login), session restore |
| `GET` | `/api/v1/mobile/auth/profile` | `myProfileEndpoint` | Profile screen |

**`/auth/me` response (`data`)**

```json
{
  "id": "…", "email": "…", "englishName": "…", "khmerName": "…",
  "empCode": "…", "phone": "…",
  "passwordChangeRequired": true, "temporaryPasswordExpiresAt": "…",
  "lastLoginAt": "…", "lineManager": { "id": "…", "empCode": "…", "englishName": "…" },
  "isAdmin": false
}
```

**`/mobile/auth/profile` response (`data`)**

```json
{
  "id": "…", "employeeCode": "…", "fullName": "…", "khmerName": "…",
  "phoneNumber": "…", "email": "…",
  "profilePhotoUrl": "…", "profilePhotoThumbnailUrl": "…",
  "role": "Sales Representative",
  "passwordChangeRequired": false, "lastLoginAt": "…",
  "lineManager": { "id": "…", "empCode": "…", "englishName": "…" }
}
```

How the app maps them (`AuthProfileModel` → `WorkerProfile`):

| API field | App field | Shown on screen |
|---|---|---|
| `englishName` / `fullName` | `fullName` | Header |
| `khmerName` | `khmerName` | Header, under the English name |
| `empCode` / `employeeCode` | `employeeId` | Header — "Employee ID" |
| `phone` / `phoneNumber` | `phoneNumber` | Contact card |
| `role` | `position` | Header — job label |
| `isAdmin: true` | role `admin` | (role label only) |
| `profilePhotoThumbnailUrl` | `avatarThumbnailUrl` | Round avatar in the header |
| `profilePhotoUrl` | `avatarUrl` | Full-screen photo when the avatar is tapped |
| `lineManager.englishName` | `lineManagerName` | Work card — "Line manager" (name only; the code is not shown) |
| `passwordChangeRequired` | `passwordChangeRequired` | Drives the forced password change |
| `temporaryPasswordExpiresAt` | `temporaryPasswordExpiresAt` | Account card — only while a temporary password is in force |
| `lastLoginAt` | `lastLoginAt` | Account card — "Last sign-in" |

> ⚠️ Neither response carries **`permissions`**. The depot sync requires
> `depots.read` or `outlets.read`, so with this backend it never runs and the
> depot list stays empty. **Decision pending:** backend adds permissions, the
> app drops the check, or the app derives them from `role`.

---

## 3. Stay signed in / sign out — 2 endpoints

| Method | App calls | Staging has | Constant | Status |
|---|---|---|---|---|
| `POST` | `/api/v1/mobile/auth/refresh-token` | `/api/v1/mobile/auth/refresh-token` | `refreshEndpoint` | ✅ Fixed 2026-10-07 |
| `POST` | `/api/v1/auth/logout` | `/api/v1/mobile/auth/logout` | `logoutEndpoint` | ⚠️ Web route, not the mobile one |

Both mobile routes take the same body:

```json
{ "refreshToken": "…" }
```

- **Refresh.** The access token lives ~15 minutes (`expiresIn: 899`). On a
  `401` the interceptor (`core/network/interceptors/auth_interceptor.dart`)
  calls `refreshEndpoint` once, stores the **new** `refreshToken` from
  `{data: {accessToken, refreshToken, …}}`, and replays the request.
  Concurrent `401`s share one refresh. Only a `400`/`401` from the refresh
  call (e.g. `AUTH_INVALID_REFRESH_TOKEN`) ends the session; no signal or a
  timeout keeps it.
- **Not `/api/v1/auth/refresh`.** That is the web portal's route: it reads the
  refresh token from a **cookie** the app does not have and never returns a new
  refresh token — reusing the old one would revoke the session. The mobile
  route also refuses portal tokens.
- **Logout.** Sign-out is local first — tokens and data are cleared even if the
  call fails — so this does not block the rep. It should still target
  `/mobile/auth/logout` so the server ends *this device's* session.

---

## 4. Change password — 1 endpoint ✅

| Method | Path | Constant | Auth |
|---|---|---|---|
| `POST` | `/api/v1/mobile/auth/change-password` | `changePasswordEndpoint` | Bearer |

```json
{ "currentPassword": "…", "newPassword": "…" }
```

Answers **`204`**. Wrong attempts count toward the account lockout. Ends the
rep's *other* sessions and keeps this one.

Used by:

- **Set Your Password** screen after a temporary-password sign-in
  (`ChangeTemporaryPasswordScreen`, via the profile `ChangePassword` use case).
  The temporary password typed at sign-in is carried over in memory so the rep
  types only the new one; on a cold start the screen asks for it. Back is
  blocked; *Sign out* is the only other exit.

---

## 5. Forgot password (SMS code) — 3 endpoints ✅

No token needed. Run in this order:

| Step | Method | Path | Constant |
|---|---|---|---|
| 1 · Send code | `POST` | `/api/v1/auth/forgot-password/request` | `sendOtpEndpoint` |
| 2 · Verify code | `POST` | `/api/v1/auth/forgot-password/verify-otp` | `verifyOtpEndpoint` |
| 3 · Reset | `POST` | `/api/v1/auth/forgot-password/reset` | `resetOtpEndpoint` |

**Step 1** — always answers `200`, whether or not the number is registered
(no account enumeration). *Resend* is this same call again.

```json
{ "recoveryMethod": "phone", "phoneNumber": "+85512345209" }
```

**Step 2** — the code is 6 digits; only the newest code counts.

```json
{ "recoveryMethod": "phone", "phoneNumber": "+85512345209", "otp": "123456" }
```

```json
{
  "data": {
    "resetToken": "…", "expiresIn": 600,
    "passwordPolicy": {
      "minLength": 8, "maxLength": 64,
      "requireUppercase": true, "requireLowercase": true,
      "requireNumber": true, "requireSpecial": true
    }
  },
  "success": true
}
```

The new-password screen checks the password against `passwordPolicy` before
sending, with a message per rule (EN + KM).

**Step 3** — the token works once; a password that fails the policy leaves it
usable. Success signs the account out everywhere.

```json
{ "resetToken": "…", "newPassword": "…", "confirmPassword": "…" }
```

`recoveryMethod` accepts only `"email"` or `"phone"` (verified on staging).
The app always sends `"phone"`.

---

## 6. Location heartbeat — 1 endpoint ❌

| Method | Path | Constant |
|---|---|---|
| `POST` | `/api/v1/mobile/auth/sessions/current/location` | `sessionsEndpoint` + `/current/location` |

```json
{ "latitude": 11.55, "longitude": 104.92, "accuracyMeters": 12.0, "capturedAt": "…" }
```

Sent by `core/session/location_heartbeat_service.dart` while a rep is signed
in. **Not on staging yet** — each heartbeat fails quietly until the backend
adds the route. Kept because location reporting is a live feature
(`mobile-location-reporting.md`).

---

## 7. Profile picture — 1 endpoint ✅

| Method | Path | Constant | Body |
|---|---|---|---|
| `POST` | `/api/v1/users/profile-photo` | `profilePhotoEndpoint` | `multipart/form-data`, image in field **`file`** — JPG, PNG or WebP, ≤ 5 MB |
| `DELETE` | `/api/v1/users/profile-photo` | `profilePhotoEndpoint` | — (`204`, also when there was no photo) |

The photo is the **only** part of the profile a rep may change. Profile screen
→ *Edit* on the avatar → take or choose a photo, or remove it → *Save*.

- The app shrinks the picture, strips location data and sends it as
  `avatar.jpg` (`image/jpeg`). The server stores a WebP and a square thumbnail.
- The photo route answers with the photo only, so the app then re-reads
  `GET /mobile/auth/profile` for the fresh signed `profilePhotoUrl` /
  `profilePhotoThumbnailUrl`, updates the cache and the shell header. If that
  re-read fails, the save still counts — the next read shows the new photo.
- **Showing it:** the round avatar uses the thumbnail, the full-screen view
  the full photo. Signed URLs work without a token until `urlExpiresAt`; a URL
  that fails (expired, offline) falls back to the rep's initials.
- **Errors** (EN + KM): `413` → "larger than 5 MB", `400` → "choose a JPG, PNG
  or WEBP photo", `429` → "too many attempts", no signal → "you're offline".

---

## Flows end to end

**Normal sign-in**

```
POST /mobile/auth/login  →  GET /auth/me  →  shell
```

**First sign-in with a temporary password**

```
POST /mobile/auth/login (passwordChangeRequired: true)
  →  GET /auth/me
  →  Set Your Password screen
  →  POST /mobile/auth/change-password
  →  shell
```

**Forgot password**

```
POST /auth/forgot-password/request
  →  POST /auth/forgot-password/verify-otp   (→ resetToken + passwordPolicy)
  →  POST /auth/forgot-password/reset
  →  sign in again
```

**Token expired (after ~15 min)**

```
any request → 401 → POST /mobile/auth/refresh-token → store new tokens → replay request
```

---

## To do

| # | Item | Owner |
|---|---|---|
| 1 | ~~Change `refreshEndpoint` to `/mobile/auth/refresh-token`~~ — done; confirm on a device after 15 min | Mobile |
| 2 | Point `logoutEndpoint` at `/mobile/auth/logout` | Mobile |
| 3 | Decide how the app gets **permissions** (§2) | Product + Backend |
| 4 | ~~Wire photo upload/remove~~ — done; confirm on a device | Mobile |
| 5 | Publish `POST /mobile/auth/sessions/current/location` (heartbeat) | Backend |
