# Request to backend: make phone password verification work on staging

**From:** mobile team · **Date:** 2026-10-23
**Environment:** staging, `https://www.pnc-spts-stg-api.me`
**Affects:** Profile → *Change password* (signed in), and Login → *Forgot password*

## TL;DR

Two things stop the app's phone password flow on staging:

1. **Configuration.** Staging runs with the default
   `PASSWORD_RESET_PHONE_CHANNEL=Backend`, so the verify endpoints answer
   `400 AUTH_PHONE_CHANNEL_DISABLED`. It needs to be `Firebase` (§3).
2. **The first step.** The app opens the flow with `POST /api/v1/auth/otp/request`.
   That endpoint issues a sign-in code. It does not open the phone verification
   that `/auth/password/phone/verify` requires. Even with (1) fixed, verify would
   answer `401 AUTH_PHONE_PROOF_INVALID`. We need a decision on how to connect them
   (§4).

---

## 1. What the app does today

| # | Call | Notes |
|---|---|---|
| 1 | `POST /api/v1/auth/otp/request` with `{ "phoneNumber": "+855…" }` | Answer: `{expiresAt, expiresIn, codeLength}` |
| 2 | Firebase `verifyPhoneNumber(+855…)` | Firebase sends the SMS, the user enters the code |
| 3 | `POST /api/v1/auth/password/phone/verify` with `{ "firebaseIdToken": "…" }` | Bearer token sent. **Fails here** |
| 4 | `POST /api/v1/auth/password` with `{ "phoneProofToken", "newPassword" }` | Not reached |

The failing response at step 3:

```json
HTTP/1.1 400 Bad Request

{
  "success": false,
  "error": {
    "code": "AUTH_PHONE_CHANNEL_DISABLED",
    "message": "Phone verification through this route is not available. Update the app.",
    "traceId": "3fb28e3b66b3fdadd2b53492361754b9",
    "details": null
  }
}
```

**Trace ID for your logs:** `3fb28e3b66b3fdadd2b53492361754b9` (2026-10-23).

Firebase did its part: the SMS arrived, the code was accepted, and the app sent a
valid ID token.

## 2. Why step 3 fails today: the API is not in Firebase mode

`VerifyOwnPhoneProofCommandHandler` in
`Backend.Modules.Identity.Application/Authentication/PhoneProof/OwnPhoneProof.cs`
refuses before it reads the token or the user:

```csharp
if (!settings.UsesFirebase)
    return PhoneVerificationErrors.ChannelDisabled;   // 400 AUTH_PHONE_CHANNEL_DISABLED
```

`UsesFirebase` (`PhoneVerificationOptions.cs` line 45) is true only when
`PASSWORD_RESET_PHONE_CHANNEL=Firebase`. The default is `Backend` (line 22). Your
`features/firebase-notifications/deployment.md` §4 describes this exact result.

Step 1 did not hit this check because `/auth/otp/request` doesn't have it. So this
is not a sign that staging's instances are configured differently.

It is not the phone number either: a missing number gives
`AUTH_PHONE_NUMBER_REQUIRED`, and the server never got as far as the user lookup.

## 3. Fix 1: configuration (needed in every case)

On every staging API instance (names from `deploy/firebase/README.md` and
`.env.example`):

```bash
PASSWORD_RESET_PHONE_CHANNEL=Firebase

# Required in Firebase mode; the API refuses to start without them:
FIREBASE_PROJECT_ID=steelforce-94963
FIREBASE_CREDENTIALS_FILE=/secrets/firebase/service-account.json   # key mounted read-only
FIREBASE_SMS_GATE_SECRET=<at least 32 bytes; same value as the function's SMS_GATE_SECRET>
```

Then restart every instance. Check that the SMS gate function is deployed with
`SMS_GATE_URL=https://www.pnc-spts-stg-api.me/api/v1/internal/firebase/sms-gate`
and the same secret. `GET /health` should not report `firebase` as `Degraded`.

## 4. Fix 2: the first step (needs a decision)

### Why `/auth/otp/request` can't open this flow

After the channel check, the verify handler requires an **open verification** for
the signed-in user, with purpose `PasswordChange`:

```csharp
var verification = await verifications.GetOpenAsync(targetHash, PhoneVerificationPurpose.PasswordChange, cancellationToken);
if (verification is null || verification.UserId != user.Id || verification.AcceptProof(now, proof.AuthTime).IsFailure)
    return await RefuseAsync(...);   // 401 AUTH_PHONE_PROOF_INVALID
```

Only `POST /auth/password/phone/start` creates that verification
(`starter.StartAsync(phoneNumber, user.Id, PhoneVerificationPurpose.PasswordChange, …)`).
`/auth/otp/request` (`RequestOtpCommandHandler`) creates a different record, a
`PhoneOtp`. It also texts its own **sign-in** code through `ISmsProvider`
(`OtpPurpose.SignIn`).

Once Firebase mode is on, there is a second effect: the SMS gate allows Firebase's
SMS only for an open verification, so Firebase's SMS would be refused too.

### Options

**Option A: the app goes back to the start endpoints (no backend code).**

| Flow | First step |
|---|---|
| Change password (signed in) | `POST /api/v1/auth/password/phone/start`, no body; the number comes from the account |
| Forgot password (signed out) | `POST /api/v1/auth/forgot-password/phone/start` with `{phoneNumber}` |

These endpoints exist on staging and were built for this, so only Fix 1 is needed.

**Option B: the backend makes `/auth/otp/request` open the phone verification
(code change).**

If the team wants one first step for every flow, `/auth/otp/request` would need to:

1. In Firebase mode, open a `PhoneVerification` through `PhoneVerificationStarter`:
   purpose `PasswordChange` for a signed-in caller, `PasswordReset` for a
   signed-out one. Apply the same limits as the start endpoints and answer with
   `phoneNumber`, `expiresIn` and `resendAfter`.
2. For a signed-in caller, **use the account's number and ignore the body**. The
   change-password rule is that the number comes from the account, never from
   the request; the start endpoint already does this.
3. Not send its own sign-in SMS when Firebase sends the code. Otherwise the user
   gets two different codes and may type the wrong one.
4. Keep the signed-out answer the same whether or not the number has an account.

Option B mixes sign-in codes and password verification in one endpoint and needs
new tests. **The mobile team prefers Option A.** Please confirm which one you want.

## 5. How to check it worked

With a signed-in test account that has a phone number, and a **real SIM**
(Firebase test numbers skip the SMS gate, so the backend refuses their proof):

| Step | Call (Option A) | Expected |
|---|---|---|
| 1 | `POST /api/v1/auth/password/phone/start` (no body) | `200` with `data.phoneNumber`, `expiresIn`, `resendAfter` |
| 2 | Firebase sends the SMS | One SMS arrives |
| 3 | `POST /api/v1/auth/password/phone/verify` with `{firebaseIdToken}` | `200` with `data.phoneProofToken` |
| 4 | `POST /api/v1/auth/password` with `{phoneProofToken, newPassword}` | `204` |

With Option B, step 1 is `POST /api/v1/auth/otp/request`, and it must give the
same results at steps 2–4.

## 6. Small doc fix (optional)

The OpenAPI description of both phone `verify` endpoints says *"Every refusal is
401 AUTH_PHONE_PROOF_INVALID."* They can also answer
`400 AUTH_PHONE_CHANNEL_DISABLED`. Please add that, as the `start` endpoints
already do.

## 7. Production

`api-dev.steelforce.app` (the app's production host) does not serve the
`/auth/password/phone/*` endpoints yet (OpenAPI checked 2026-10-22). It will need
Fix 1 once they are deployed there.

---

Questions: mobile team. Contract: [mobile-integration.md](mobile-integration.md),
Flow A and Flow B.
