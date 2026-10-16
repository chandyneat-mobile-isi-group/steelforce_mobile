# US-05 — Resume an Interrupted Registration

**Role:** Sales Representative
**Use case:** [UC-07 Registration Draft Lifecycle](../usecases/registration-draft-lifecycle.md)
**APIs:** `GET /mobile/depots/draft/active`, `POST /mobile/depots/draft`, `POST /mobile/depots/update`
**Screen:** `DepotCreateScreen`

---

## Story

> As a **Sales Representative**,
> I want **a half-finished registration to still be there when I come back**,
> so that **I do not have to re-enter 47 fields because my phone died**.

---

## Acceptance criteria

- [ ] On opening the registration form, the app checks for an existing open draft.
- [ ] A resumable draft is reopened at the step the rep left.
- [ ] A draft that is **not** resumable is replaced by a fresh one.
- [ ] Each completed step patches the draft server-side, sending **only changed fields**.
- [ ] The rep can abandon a draft and start over.
- [ ] Having no draft is a **normal** outcome, never an error message.
- [ ] Resuming works after the app is force-killed, the device restarts, or the rep signs in on another handset.

## Main scenario

1. Rep opens the registration form.
2. `GET /mobile/depots/draft/active`.
3. A draft comes back with `isEditable: true`, `status: "Draft"` → **resumable**.
4. The form is rehydrated from `fields`.
5. The rep continues; each step sends `POST /update`.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| `404` | No open form → create a fresh draft. **Not an error** (BR-14) |
| `200` with `data: null` | Same as 404 |
| `200` but `draftId` is empty | Treated as absence; a warning is traced |
| Server has not deployed the endpoint | Also answers `404` → the app still works |
| `status: "Submitted"` / `"Registered"` / `"Rejected"` | **Not** resumable → fresh draft |
| `isEditable: false` but `status: "Draft"` | **Not** resumable — the restrictive reading wins (BR-15) |
| Rep abandons | `DELETE /mobile/depots/draft/{draftId}` |
| Server adds a new SAP field | Appears in `fields`; the app does **not** need a release |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| `4xx` on update | `ValidationFailure` — the rep must fix a field; not retried |
| `5xx` on update | Retryable; local form state is not lost |
| `fields` returned as a non-object | Degrades to `{}` rather than throwing |
| Unrecognised `status` | Degrades to "not resumable", **never throws** |
