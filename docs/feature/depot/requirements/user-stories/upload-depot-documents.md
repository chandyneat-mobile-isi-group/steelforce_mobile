# US-07 — Upload Depot Documents

**Role:** Sales Representative
**Use case:** [UC-10 Manage Depot Documents](../usecases/manage-depot-documents.md)
**APIs:** `POST` / `GET` / `DELETE` `/api/v1/mobile/depots/{depotId}/documents`
**Screen:** `documents_step.dart`

---

## Story

> As a **Sales Representative**,
> I want to **attach a trade licence and photos to a depot**,
> so that **HQ has what it needs to approve the registration**.

---

## Acceptance criteria

- [ ] The rep can attach a file to a named slot from the camera or the file picker.
- [ ] Files over **10 MB** are rejected **before** upload, with a clear message.
- [ ] Upload progress is visible.
- [ ] An uploaded document shows its name and a preview or icon.
- [ ] The rep can replace or remove a document.
- [ ] Documents already attached are listed when the step is reopened.
- [ ] A failed upload can be retried without redoing the rest of the form.
- [ ] Captured images are held via the encrypted capture path, not written to shared storage.

## Main scenario

1. Rep taps a document slot.
2. Picks or captures a file.
3. Size is checked client-side.
4. `POST …/documents` as multipart with `file` and `kind`.
5. The stored document renders against its slot.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| File > 10 MB | Rejected client-side; not sent |
| Replace | Re-upload to the same slot |
| Remove | `DELETE …/documents/{documentId}` |
| Offline | Retryable; the local file is kept |
| Several documents | Uploaded **one at a time — there is no batch endpoint**, so a failure names the file that failed |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| Unsupported type | `TODO / Backend Confirmation Required` — the allowed content types are not pinned |
| Unknown `kind` | `TODO / Backend Confirmation Required` — the allowed slot names are not pinned |
| `413` from the server | Shown as a size error, not a generic failure |
| `4xx` | `ValidationFailure`; not retried |
| `5xx` | Retryable |

> **Not the same endpoint as registration attachments.** Those go to
> `POST /api/v1/depots/bp/{localId}/attachments`, which has a different route
> shape and response envelope — see [UC-09](../usecases/create-business-partner.md#a-15--post-apiv1depotsbplocalidattachments).
