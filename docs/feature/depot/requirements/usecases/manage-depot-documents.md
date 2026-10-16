# UC-10 — Manage Depot Documents

| | |
|---|---|
| **APIs** | `POST` / `GET` / `DELETE` `/api/v1/mobile/depots/{depotId}/documents` |
| **Mobile interface** | `DepotDocumentRepository` |
| **Consumes into** | `DepotDocument` |
| **Screen** | `documents_step.dart` in the registration flow |
| **User story** | [US-07](../user-stories/upload-depot-documents.md) |

---

## Use case

**Description.** Attach supporting documents to a depot — trade licence, tax
certificate, shopfront photo — and list or remove them.

**Actor.** Sales Representative.

**Preconditions.** Authenticated; the depot exists.

### Main flow

1. The rep picks or captures a file for a named slot.
2. `POST …/documents` as multipart.
3. The stored document is returned and shown against its slot.

### Alternative flows

| Flow | Behaviour |
|---|---|
| Replace | Upload again to the same slot |
| Remove | `DELETE …/documents/{documentId}` |
| Review | `GET …/documents` |

### Error flows

| Condition | Result |
|---|---|
| File > **10 MB** | Rejected **client-side** before the request |
| 4xx | `ValidationFailure` |
| 5xx / offline | Retryable; the local file is kept |

### Business rules

**BR-18.** Max 10 MB (`maxBytes = 10 * 1024 * 1024`). **One file per slot —
there is no batch endpoint**, deliberately: a failed batch leaves the rep unable
to tell which file failed.

---

## A-16 · Upload

```http
POST /api/v1/mobile/depots/{depotId}/documents HTTP/1.1
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

| Part | Type | Required | Description |
|---|---|---|---|
| `file` | binary | **Yes** | ≤ 10 MB |
| `kind` | string | **Yes** | Slot name. **`TODO / Backend Confirmation Required`** — the allowed set |

| Path parameter | Type | Required |
|---|---|---|
| `depotId` | string (GUID) | Yes |

### Response

```json
{
  "success": true,
  "data": {
    "id": "doc-7781",
    "kind": "TradeLicence",
    "fileName": "licence.pdf",
    "url": "https://cdn.example.com/depots/…/licence.pdf",
    "sizeBytes": 284512,
    "contentType": "application/pdf",
    "uploadedAt": "2026-09-25T04:30:00Z"
  }
}
```

### Response mapping — `DepotDocument`

| Backend field | Type | Required | Mobile field | Mapping |
|---|---|---|---|---|
| `id` | string | Yes | `id` | direct |
| `kind` | string | Yes | `kind` | the slot |
| `fileName` | string | Yes | `fileName` | direct |
| `url` | string | Yes | `url` | direct |
| `sizeBytes` | number | No | `sizeBytes` | — |
| `contentType` | string | No | `contentType` | — |
| `uploadedAt` | ISO-8601 | No | `uploadedAt` | `String` → `DateTime` |

> **`TODO / Backend Confirmation Required`** — these field names are inferred
> from `DepotDocument` and `depot_document_mapper.dart`. Confirm each against the
> mapper before implementing.

## A-17 · List

`GET /api/v1/mobile/depots/{depotId}/documents` → `data` array of the above.

## A-18 · Delete

`DELETE /api/v1/mobile/depots/{depotId}/documents/{documentId}` → `204`.

---

## Mobile compatibility notes

1. The **10 MB cap is enforced client-side**; the server should enforce it too
   and return a clear code rather than a generic 413.
2. Not to be confused with **A-15**, the *registration* attachment endpoint,
   which has a different route and envelope — see
   [UC-09](create-business-partner.md#a-15--post-apiv1depotsbplocalidattachments).
