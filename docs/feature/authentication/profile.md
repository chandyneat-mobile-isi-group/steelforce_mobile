# My Profile — Mobile & Web Integration Guide

**Audience:** mobile and admin-portal developers.
**Scope:** a user's own profile and an administrator's edit of any user's profile,
including the profile avatar.
**Status:** Active · **Last updated:** 2026-09-17

**Implementation:** `src/ISI.Api/Controllers/Users/ProfileController.cs` ·
`src/ISI.Api/Controllers/Administration/UsersController.cs` ·
`src/ISI.Application/Features/Users/UpdateProfile/` ·
`src/ISI.Identity/Services/IdentityService.cs`

---

## The routes you need

| Actor | Operation | Route |
|---|---|---|
| Any signed-in user | Read own profile | `GET /api/v1/auth/me` |
| Any signed-in user | Write own profile + avatar | `PUT /api/v1/users/me/profile` |
| Administrator | Write another user's profile + avatar | `PUT /api/v1/users/{userId}/profile` |
| Administrator | Read the directory (now carries `avatarUrl`) | `GET /api/v1/users` |

The two self-service routes share the **same** `EmployeeProfileResponse`, so after a
successful save replace your cached profile with the response body rather than
re-fetching `/auth/me`. The administrator route returns `UserDetailsResponse` instead —
the directory shape, with roles and lockout.

> **Neither of these is `PUT /api/v1/users/{userId}`.** That route stays JSON and keeps
> `roles` and `isActive`. It was deliberately **not** turned into a multipart upload:
> doing so would break every existing portal caller and would mix a file upload into the
> one request that can also grant privilege. Profile-and-avatar edits go to the
> `/profile` sub-routes above; role and status changes stay where they are.

---

## 1. Update my profile

`PUT /api/v1/users/me/profile`

**Content type: `multipart/form-data`.** Not JSON — the same request may carry an
image.

**Authentication:** any signed-in user. No permission is required, because the account
being edited is taken from your access token. There is no user id in the URL or the
body, so there is nothing to get wrong: you can only ever edit yourself.

### Form fields

| Field | Type | Notes |
|---|---|---|
| `fullName` | string | 2–128 chars. Cannot be blanked — omit it to keep the current name. |
| `jobTitle` | string | Up to 128 chars. Send `""` to clear. |
| `preferredLanguage` | string | BCP 47, e.g. `km-KH`, `en-US`. Send `""` to clear. |
| `timeZoneId` | string | IANA, e.g. `Asia/Phnom_Penh`. Send `""` to clear. |
| `avatar` | file | JPG / JPEG / PNG / WEBP, max **2 MB**. Sets or replaces the picture. |
| `removeAvatar` | bool | `true` deletes the current picture. |

**Every field is optional. Send only what changed.** An omitted field is left alone;
an empty string clears a nullable field. This is why a client changing only the avatar
does not have to resend the name.

**`avatar` and `removeAvatar=true` together are rejected** (`400`,
`User.AvatarUploadAndRemovalConflict`). They mean opposite things, and guessing which
you meant is how a user who wanted a new photograph ends up with none.

**A request that changes nothing is also rejected** (`400`,
`User.ProfileUpdateEmpty`) rather than silently succeeding. The usual cause is a form
field the client failed to attach.

### What you cannot change here

| Field | Why | Where instead |
|---|---|---|
| `email`, `phoneNumber` | Sign-in credentials. The phone number is where the mobile OTP is sent, so changing it is an account-recovery operation needing its own verification step. | Not yet available — see Limitations |
| `employeeCode`, `territoryCode`, `depotCode` | Owned by HR and SAP. Reassigning your own territory would silently change which customers you can see. | Administrator |
| `roles`, `isActive` | Privilege. Self-service would be escalation. | Administrator |

### Example — change the name and the picture in one call

```http
PUT /api/v1/users/me/profile
Authorization: Bearer <access token>
Content-Type: multipart/form-data; boundary=----X
```

```
------X
Content-Disposition: form-data; name="fullName"

Sok Visal
------X
Content-Disposition: form-data; name="avatar"; filename="me.jpg"
Content-Type: image/jpeg

<binary>
------X--
```

### Example — remove the picture, change nothing else

```
------X
Content-Disposition: form-data; name="removeAvatar"

true
------X--
```

### Response (`200 OK`)

The platform's standard envelope wrapping `EmployeeProfileResponse`:

```json
{
  "success": true,
  "data": {
    "userId": "0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b",
    "employeeId": "EMP000250",
    "fullName": "Sok Visal",
    "email": "sok.visal@isigroup.com.kh",
    "phoneNumber": "012345999",
    "avatarUrl": "/files/avatars/k3nR8xQ2mZ7pL4vT1wY6bA",
    "department": "Field Sales",
    "position": "Sales Supervisor",
    "territoryCode": "PP-SOUTH",
    "depotCode": "DEPOT-PP02",
    "roles": ["Supervisor"],
    "permissions": ["customers.read", "visits.create"],
    "featureFlags": { "offlineSync": true },
    "language": "km-KH",
    "timeZone": "Asia/Phnom_Penh",
    "theme": null,
    "passwordExpiresAt": null,
    "lastLoginAt": "2026-09-17T01:12:44Z"
  },
  "meta": { }
}
```

`avatarUrl` is `null` for a user who has never set a picture — which is every existing
account. Render your placeholder initials in that case.

### Errors

| Status | Code | Meaning |
|---|---|---|
| `400` | `User.ProfileUpdateEmpty` | Nothing was sent to change. |
| `400` | `User.AvatarExtensionNotAllowed` | Not a JPG, JPEG, PNG or WEBP. |
| `400` | `User.AvatarContentTypeMismatch` | The declared type and the file name disagree. |
| `400` | `User.AvatarTooLarge` | Over 2 MB. |
| `400` | `User.AvatarUploadAndRemovalConflict` | A file and `removeAvatar=true` together. |
| `400` | `General.Validation` | Blank `fullName`, bad language tag, over-length field. |
| `401` | — | No token, or an expired one. |
| `500` | `User.AvatarStorageFailed` | The image could not be written. Safe to retry. |

---

## 1b. Administrator: update another user's profile

`PUT /api/v1/users/{userId}/profile` - **`users.update`**

Identical form fields, identical avatar rules, identical partial-update semantics as
section 1 - it runs through the *same* service method, so the accepted formats, the 2 MB
ceiling, the new-token-on-replace behaviour and the delete-the-old-file-only-after-the-
row-saves ordering cannot drift between the two paths.

Two differences:

- The subject is named in the URL instead of taken from the token. The protection moves
  to the permission: `users.update`, the same one that already governs editing another
  user's name and job title. Nobody gains reach they did not already have.
- It returns `UserDetailsResponse` (the administration shape - roles, lockout, audit
  columns) rather than `EmployeeProfileResponse`.

**Still not settable here:** roles, active status, email, phone number, employee code,
territory, depot. A profile edit can never become a privilege change.

### Avatars in the user list

`GET /api/v1/users` now returns `avatarUrl` on every row, so the directory's avatar
column can render without a per-row call. It is `null` for users who have not set one -
which is every account until somebody does.

**Creating a user with an avatar** is two calls: `POST /api/v1/users` (JSON) to create,
then `PUT /api/v1/users/{userId}/profile` (multipart) with the image. `POST` was left
JSON for the same reason as `PUT /users/{userId}` - see the note above.

---

## 2. Display an avatar

`GET /files/avatars/{token}` — **anonymous**, no `Authorization` header.

`avatarUrl` is a ready-to-use address. Put it straight in an image tag:

```html
<img src="/files/avatars/k3nR8xQ2mZ7pL4vT1wY6bA" alt="">
```

```dart
Image.network('$apiBaseUrl${profile.avatarUrl}')
```

The route is anonymous because an `<img>` tag cannot send a bearer token. What
protects the image is the address: the token is 128 random bits rather than a user
id, so the route cannot be walked to collect staff photographs, and a deleted account
stops resolving.

**Cache it freely.** Responses carry
`Cache-Control: public, max-age=31536000, immutable`. One URL only ever addresses one
image, so it can never go stale.

**Never build this URL yourself, and never keep an old one.** Replacing an avatar
mints a **new** token, and the previous URL stops working immediately. Always use the
`avatarUrl` from the most recent profile response.

---

## 3. Client checklist

1. Downscale before uploading. The avatar renders at header size; a full-resolution
   camera photograph is a slow upload on a provincial connection for no visible gain.
   Target ~512 px and re-encode as JPEG.
2. Send only changed fields. The endpoint is a partial update by design.
3. Replace the cached profile from the response rather than re-fetching `/auth/me`.
4. Handle `avatarUrl: null` — it is the state of every account until someone sets a
   picture.
5. Do not cache the avatar URL separately from the profile. They change together.

---

## Limitations

- **No self-service phone or email change.** Both are sign-in credentials and need a
  verification flow that does not exist yet. An administrator can change them today.
- **No server-side image processing.** The bytes are stored as uploaded — there is no
  resizing, re-encoding, EXIF stripping or thumbnail generation. Clients must downscale.
  EXIF orientation and GPS tags survive, so a photograph taken in the field carries its
  capture location into a publicly addressable file. Stripping metadata server-side is
  the obvious next step if that matters.
- **No content inspection.** The platform checks the extension and the declared MIME
  type agree; it does not decode the image to confirm it is one. The file is always
  served back with a fixed image content type and never executed.

---

## Related

- [api/admin.md](admin.md) — the administrator's user management surface
- [../security.md](../security.md) — permissions and the self-lockout problem
- [../../authentication/](../../authentication/) — signing in, sessions, `/auth/me`
