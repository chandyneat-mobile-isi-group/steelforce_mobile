# Test case coverage — Authentication & Profile

**Scope of this round:** Authentication (login, temporary password, forgotten
password by SMS, guest), Session (restore, token refresh, expiry, sign-out,
rep switch) and Profile. Other features are out of scope for now.

**Source:** every case comes from the code on branch `uat` at `644056f`
(app `1.0.0+1`). Each row in `Test_Cases` has a **Code Reference** column. If
the code and a case disagree, the code describes what the app does today; the
difference is a finding, not a reason to edit the case quietly.

Workbook: [`SteelForce_Test_Cases.xlsx`](SteelForce_Test_Cases.xlsx).

---

## 1. Summary

| Module | Cases | P1 | P2 | P3 | Automated | Partial | Manual (planned) |
|---|---|---|---|---|---|---|---|
| Authentication | 20 | 13 | 7 | 0 | 5 | 6 | 9 |
| Session | 10 | 9 | 1 | 0 | 8 | 0 | 2 |
| Profile | 6 | 2 | 3 | 1 | 4 | 1 | 1 |
| **Total** | **36** | **24** | **11** | **1** | **17** | **7** | **12** |

- **Automated:** an existing test in `test/` checks the behaviour.
- **Partial:** an automated test checks part of it, and a manual UAT run is still needed.
- **Planned:** manual only for now.

Every case should still run **once on a real device against UAT** before
release, because automated tests use fakes, not the real backend.

Case types: Functional 13, Negative 10, Security 6, Offline 3, UI 2,
Localization 1, API 1.

The 9 end-to-end scenarios in `Test_Scenarios` chain these cases into real rep
journeys: first sign-in, daily sign-in, SMS reset, failure modes, a full
working day, revoked session, handing the phone over, and two for profile.

## 2. Automated evidence (real run)

On **2026-10-08** I ran every authentication, profile and session test file:

```
flutter test test/features/authentication test/features/profile \
  test/core/network/auth_interceptor_test.dart test/core/session
→ 195 tests, all passed
```

`Execution_Results` records this as run `AUTO-2026-10-08`: 22 rows, one per
case, each with its test file and pass count. `TC-AUTH-017` and `TC-PRO-002`
rely on `test/features/shell/guest_home_screen_test.dart`, which wasn't part
of this run, so they have no automated row yet.

The manual UAT run `UAT-R1` is pre-filled as **Not Run** for all 36 cases.

## 3. Coverage by area

| Area | Cases | What's covered | Gap |
|---|---|---|---|
| Login validation & success | AUTH-001…004, 016, 017 | Remember-me, guest, layout, failure mapping | No widget test for the validators or the error pill |
| Login failures | AUTH-005…007, 018, 019 | — | **No automated test** for offline, unreachable, 5xx, locked or inactive accounts |
| Temporary password | AUTH-008…010 | Policy, success, cached flag | Splash routing untested |
| Forgotten password | AUTH-011…015, 020 | Request, verify, policy | OTP screen UI (cooldown, auto-submit) untested |
| Session & token | SES-001…010 | Refresh/replay, 403, rejection, logout, wipe, reset | Offline restore (AuthBloc) and expiry UX untested |
| Profile | PRO-001…006 | Load/cache, photo, errors, details | Change-password entry point untested |

## 4. Suspected issues to verify in UAT

These came from reading the code. They aren't confirmed bugs, and the
`Bug_Log` stays empty until a test run proves them. Each one has a case
designed to show it.

| Case | What the code does today | Why it matters |
|---|---|---|
| TC-SES-009 | After the session expires nothing returns the rep to login; calls simply fail with “Your session expired…”. Only the heartbeat and notification services listen for expiry. | The rep may keep working without knowing nothing is saved to the server. The expected UX needs a business decision. |
| TC-AUTH-020 | The forgot-password, OTP and reset screens show the failure message as-is, so offline shows English “No internet connection.” in a Khmer session (`app_page.dart:139,165,245`). | Localization |
| TC-AUTH-013 | A failed resend is ignored, and the 30 s cooldown restarts anyway (`verify_screen.dart:111-121`). Blocked or expired codes have no dedicated handling. | The rep waits for an SMS that was never sent. |
| TC-PRO-005 | The profile "Change password" tile opens the SMS reset flow, not the change-password form (`profile_screen.dart:139-144`). | Confirm this is intended. |
| — | A missing reset grant sends an empty `resetToken` (`app_page.dart:162`). | Hard to reach by hand; worth a unit test. |

## 5. Test data

`Test_Data` lists the 10 data items these cases need (TD-001…TD-008,
TD-018, TD-019): the account types, phones, password candidates, network
conditions and photos. **The workbook never holds a password.** It names the
secret-store entry to use, and the QA lead hands out the values.
