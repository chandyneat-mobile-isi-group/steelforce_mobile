# UC-07 — Registration Draft Lifecycle

| | |
|---|---|
| **APIs** | 7 endpoints under `/api/v1/mobile/depots` |
| **Mobile interface** | `DepotRemoteDataSource` (`data/remote/depot_datasources.dart`) |
| **Consumes into** | `DepotRegistrationDraft`, `CreateBpResponse` |
| **Screen** | `DepotCreateScreen` (multi-step) |
| **User story** | [US-04](../user-stories/register-new-depot.md), [US-05](../user-stories/resume-registration-draft.md) |

---

## Why the draft lives on the server

The SAP registration form is **47 fields across 6 steps**. A rep fills it
standing in a shop, often on a low-end handset that the OS may kill at any
point. A server-side draft means a killed handset resumes where it left off
instead of starting over.

`fields` is deliberately a **`Map<String, dynamic>`**, not a typed model: the
API owns the 47-field SAP schema and can add a field **without breaking an
already-released mobile app**.

---

## Use case

**Actor.** Sales Representative.

**Preconditions.** Authenticated. References loaded ([UC-08](fetch-references.md)).

### Main flow

```
GET  /draft/active ──► none (404 / null) ──► POST /draft ──► draftId
                  └──► resumable draft   ──► resume it
                                              │
              per step: POST /update {draftId, fields:{…changed}}
                                              │
                                         POST /submit {draftId}
                                              │
                                    CreateBpResponse (SAP)
```

### Alternative flows

| Flow | Behaviour |
|---|---|
| Existing resumable draft | Reopened rather than replaced |
| Draft exists but not resumable | A fresh draft is created |
| Rep abandons | `DELETE /draft/{draftId}` |
| Rep has several drafts | `GET /drafts` lists them |

### Error flows

| Condition | Result |
|---|---|
| `GET /draft/active` → 404 | **"No open form" — a normal answer**, not an error (BR-14) |
| `GET /draft/active` → 200 with `data: null` | Treated as absence |
| `GET /draft/active` → 200 with no `draftId` | Treated as absence, warning traced |
| 4xx on any call | `ValidationFailure` — the rep must fix a field |
| 5xx / transport | Retryable |

### Business rules

BR-14, BR-15 — see [`../README.md`](../README.md#10-business-rules).

---

## A-07 · `POST /mobile/depots/draft`

Create a new server-side draft. **No request body.**

```json
{
  "success": true,
  "data": {
    "draftId": "d-9f1e2b3c",
    "fields": { "Name1": "", "City": "", "Country": "KH" },
    "status": "Draft",
    "isEditable": true,
    "submittedDepotId": null
  }
}
```

## A-08 · `GET /mobile/depots/draft/active`

The rep's current open form, or nothing.

| Response | Mobile result |
|---|---|
| `200` + `data.{draftId,…}` | `DepotRegistrationDraft` |
| `200` + `data: null` | `null` — create a fresh draft |
| **`404`** | **`null`** — no draft, *or* the server has not deployed this endpoint. Both mean "create a fresh draft" |

> The client reads this envelope **defensively**, not through `ApiEnvelope`,
> because a server with no active draft may answer `200` with `"data": null`,
> which `ApiEnvelope` treats as malformed.

## A-09 · `GET /mobile/depots/draft/{draftId}` · A-10 · `GET /mobile/depots/drafts`

Single draft, and the list. The list response is read tolerantly:
`data.drafts` **or** `data.items` **or** `data` itself as an array.
**`TODO / Backend Confirmation Required`** — pick one and document it.

## A-11 · `POST /mobile/depots/update`

**Patch semantics.**

```json
{ "draftId": "d-9f1e2b3c", "fields": { "City": "Phnom Penh", "Street": "St. 271" } }
```

| Field | Type | Required | Description |
|---|---|---|---|
| `draftId` | string | Yes | The draft being patched |
| `fields` | object | Yes | **Only the changed keys.** The server must distinguish an omitted field from one explicitly set to `""` |

Returns the full updated draft.

## A-12 · `POST /mobile/depots/submit`

```json
{ "draftId": "d-9f1e2b3c" }
```

Returns a `CreateBpResponse` — see [UC-09](create-business-partner.md#response-mapping).

## A-13 · `DELETE /mobile/depots/draft/{draftId}`

Discard. Expects `204`.

---

## Response mapping — `DepotRegistrationDraft`

| Backend field | Type | Required | Mobile field | Mapping / fallback |
|---|---|---|---|---|
| `draftId` | string | **Yes** | `draftId` | `''` fallback; an empty id is treated as "no draft" |
| `fields` | object | Yes | `fields` (`Map<String,dynamic>`) | `{}` fallback. **Untyped on purpose** — a new SAP field must not need an app release |
| `status` | string | No | `status` (**raw string**) | Defaults to `"Draft"`. **Kept as a string, not an enum** — an unrecognised value must degrade to "not resumable", never throw |
| `isEditable` | boolean | No | `isEditable` | Defaults `true` |
| `submittedDepotId` | string \| null | No | `submittedDepotId` | Set once the draft has become a real depot |

### Derived: `isResumable`

```dart
isResumable = isEditable && status.toLowerCase() == "draft"
```

**Both conditions are checked deliberately.** `status` is the documented
contract; `isEditable` is the server's own verdict. If they disagree, the
restrictive reading wins — resuming a draft the server considers closed would
send the rep's edits into a record that can no longer accept them.

Known non-draft statuses: `Submitted`, `Registered`, `Rejected`.
**`TODO / Backend Confirmation Required`** — the full status list.

---

## Mobile compatibility notes

1. **404 on `/draft/active` must stay "absence", not an error.** The client
   depends on it, and it is also how a server without the endpoint behaves.
2. **Defaults describe a fresh draft.** Omitting `status`/`isEditable` is read
   as `Draft` / editable — which is what `POST /draft` means.
3. **Do not type `fields`.** The whole point of the map is forward compatibility.
4. `GET /drafts` accepts three shapes today. Pin one.
