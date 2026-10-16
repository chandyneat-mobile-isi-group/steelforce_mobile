# US-04 — Register a New Depot

**Role:** Sales Representative
**Use cases:** [UC-08](../usecases/fetch-references.md) → [UC-04](../usecases/lookup-depot-by-code.md) → [UC-07](../usecases/registration-draft-lifecycle.md) → [UC-09](../usecases/create-business-partner.md) (or [UC-03](../usecases/create-depot.md))
**Screen:** `DepotCreateScreen` · `AddDepotBloc`

---

## Story

> As a **Sales Representative**,
> I want to **register a new shop as a depot while I am standing in it**,
> so that **I can start selling to it without going back to the office**.

---

## Acceptance criteria

- [ ] The rep can start a registration from the depots screen.
- [ ] The form is stepped: identity → address → contact → sales terms → documents → review.
- [ ] Dropdowns are populated from the SAP reference catalogues, **active codes only**.
- [ ] The depot code is checked before submission; an existing code blocks registration.
- [ ] Progress is saved to a **server-side draft** after each step, so a killed app resumes.
- [ ] GPS coordinates are captured when available and **omitted entirely** when not — never sent as `(0,0)`.
- [ ] The rep can review everything before submitting.
- [ ] Submission shows progress and a clear outcome, including the SAP result.
- [ ] A created depot appears in the list as `Draft` and **cannot trade** until approved.
- [ ] The form works offline: the submission is queued and retried.
- [ ] All labels and validation messages are localised (EN + KM).
- [ ] The layout adapts to phone and tablet (`mobile_layout.dart` / `tablet_layout.dart`).

## Main scenario

1. Rep taps "Add depot".
2. References load ([UC-08](../usecases/fetch-references.md)).
3. A draft is created or resumed ([UC-07](../usecases/registration-draft-lifecycle.md)).
4. Rep enters the depot code; it is checked ([UC-04](../usecases/lookup-depot-by-code.md)) and is absent.
5. Each completed step patches the draft.
6. Rep reviews and submits → SAP ([UC-09](../usecases/create-business-partner.md)).
7. Outcome is shown; the depot appears as `Draft`.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| Code already exists | Registration blocked; the existing depot is shown instead |
| ERP unreachable on the code check (`502`) | **Registration is not offered** — proceeding would create a duplicate BP (BR-17) |
| No GPS fix | Coordinates omitted; the rep is not blocked |
| Offline | Queued as a `PendingSubmission`, retried on reconnect |
| App killed mid-form | Resumed from the server draft ([US-05](resume-registration-draft.md)) |
| SAP approval pending | `sapStatus: PENDING_HQ`, `customerCode: null` — shown as "awaiting HQ" |

## Validation / error scenarios

| Field / condition | Expected |
|---|---|
| Missing `Name1` / `shopName` | Blocked client-side |
| Invalid `type` | `General.Validation` — **not** `Depot.TypeInvalid` |
| Duplicate `depotCode` | `409 Depot.DuplicateCode` → inline error on the code field |
| `(0,0)` coordinates | `Depot.CoordinatesMissing` |
| Only one of lat/lng | `400` |
| `creditLimit` < 0 | Rejected |
| `creditTermDays` outside 0–180 | Rejected |
| Phone with spaces or dashes | **Accepted** — never make the rep retype because of a space (BR-06) |
| SAP push times out | **Must not be retried blindly** — SAP may have completed it; retrying creates a duplicate (BR-16) |
| SAP returns `E`/`A`/`X` | Treated as failure; the SAP message is shown to the rep |
