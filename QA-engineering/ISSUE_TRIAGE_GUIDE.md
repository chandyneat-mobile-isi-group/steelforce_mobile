# Issue triage — finding where a failure comes from

A failed test is not finished until it says **where** the problem is and **how
sure we are**. A failure on the phone does not mean the mobile app is the
cause: the request passes through the network, the backend, the database and
sometimes SAP.

```
Mobile app ──► Network ──► Backend API ──► Database
                                  └──────► SAP / external systems
```

The workbook records this in `Execution_Results` (Issue Source, Issue Type,
HTTP Status, Correlation ID, Root Cause, Confidence, Assigned Team). Its
**Triage Check** column flags a failure that is missing something.
`Triage_Matrix` is the quick lookup table; this page explains how to use it.

---

## 1. Evidence the app already gives you

SteelForce prints one log line for every API call in a debug build. These
lines appear in the `flutter run` console and in DevTools, tagged `isi.debug`
or `isi.error`. They come from `lib/core/network/interceptors/api_log_interceptor.dart`.

| Log line | Fields | What it tells you |
|---|---|---|
| `api.request` | method, path, queryKeys, **correlationId**, language | The app sent the request. If this line is missing, the app never tried. |
| `api.response` | method, path, **status**, ms, signedIn, payload shape (item counts) | The server answered, and how much data it sent. |
| `api.error` | method, path, **host**, **status**, ms, signedIn, **errorCode**, **correlationId**, **dioType**, invalidFields | Why the call failed. |

- **Correlation ID.** Every request sends a fresh `X-Correlation-Id`. Copy it
  into the workbook; Backend uses it to find the exact server log.
- **Request bodies.** To see the body, run with
  `--dart-define=API_LOG_BODIES=true`. Bodies are redacted, and the flag is
  ignored in release builds. Use it on your own machine only.
- **Never paste** passwords, tokens, OTP codes or full phone numbers into the
  workbook. Mask them, for example `012***678`.

## 2. Investigation order

Work down the list. Don't stop at the first error you see.

1. **Mobile behaviour.** Screenshot, screen name, steps, device and OS, app version.
2. **Was a request sent?** Look for the `api.request` line. None means the app
   never called the server, so this is Mobile (or a client-side validation
   rule that worked as designed).
3. **Where did it go?** Check `host` on `api.error`. A host other than UAT
   means the build is wrong (Environment): the `.env` values are compiled into
   the app at build time.
4. **What came back?** Check `status`, `errorCode` and `dioType`, then use the
   table in §3.
5. **Was the response right?** Compare the body with
   `docs/feature/<feature>/api.md`. A correct body shown wrongly is Mobile. A
   wrong body is Backend.
6. **Database or SAP.** Only with backend evidence: the server log found by
   Correlation ID, the stored record, or the SAP response.
7. **Write the result.** Root Cause and Confidence. If evidence is missing,
   name it.

## 3. Reading the signals

| Signal | Likely source | Notes |
|---|---|---|
| No `api.request`, and the app showed a validation message | Not a bug | Client-side rule worked. |
| No `api.request` when one was expected | Mobile | |
| `dioType=connectionError` and the device is offline | Network | |
| “Cannot reach the ISI server.” while the device is online | Environment | Check `host`. Wrong host means a bad build; right host means UAT, the tunnel or the VPN is down. |
| `dioType=connectionTimeout` (15 s) | Network | The server never saw the request. |
| `dioType=receiveTimeout` / `sendTimeout` | **Unknown, Low** | The request was sent and may have been processed. Search the backend log by Correlation ID first. |
| HTTP 5xx on a request that matches the contract | Backend | |
| 400/422 `General.Validation` with `invalidFields` | Mobile or Backend | The field breaks the contract: Mobile. The field is valid per the contract: Backend. |
| 401 `Auth.InvalidCredentials` / `AccountLocked` / `AccountInactive` / `PasswordExpired` at login | Test Data | Check the account in the admin portal first. |
| 401 on a signed-in call that doesn't recover | Mobile or Backend | `signedIn=false` means Mobile didn't attach the token. `signedIn=true` with a fresh token means Backend. |
| 403, with or without `Auth.PermissionDenied` | Test Data | The role lacks the permission. Correct role but still refused: Backend. |
| 429 `General.TooManyRequests` | Environment | Unless the test fired too fast. |
| 200 with a correct body, wrong value on screen | Mobile | |
| 201 succeeds, but the record is missing or wrong when read back | Database | Needs backend evidence; otherwise Unknown. |
| `Sap.ApiError`, or a backend log showing SAP rejected the call | SAP | |
| Layout overflow, clipped Khmer, wrong copy or navigation, crash | Mobile | |

## 4. Confidence

| Level | Use when |
|---|---|
| **High** | The evidence points at one layer and rules out the others, e.g. a valid request, 500, and a backend stack trace. |
| **Medium** | The evidence points at one layer but one check is missing, e.g. a 500 without the backend log yet. |
| **Low** | There isn't enough evidence. **Issue Source = Unknown must always be Low.** |

## 5. Writing it up

Don't write just "Test failed." Write, for example:

> **Test failed — likely Backend.** The mobile request matches the contract
> (`POST /api/v1/mobile/auth/change-password`). The server answered HTTP 500,
> correlation id `3f2a…`, and the temporary-password flag was not cleared.
> Confidence: Medium, because the backend log has not been checked yet.
> Assigned: Backend.

For an Unknown result, list exactly what is missing, for example:
*"Root cause not determined. Needed: backend log for correlation id …,
request/response body, user record in the portal."*

Raise a `Bug_Log` row when the cause is confirmed (High) or the failure blocks
testing. Put the Bug ID in `Execution_Results` and name a regression test case.

## 6. Known noise (don't raise a new bug)

- `POST /api/v1/mobile/auth/sessions/current/location` returns 404 on staging.
  The location heartbeat endpoint isn't deployed there yet, as documented in
  `lib/core/network/api/api_endpoints.dart`.
