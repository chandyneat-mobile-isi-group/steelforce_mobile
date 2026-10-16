# Depot — User Stories

Written from the field sales rep's perspective. Each story names its use case
and its API, so the chain from a rep's need to a backend endpoint is traceable
in one hop.

```
User Story → Use Case → API → Request → Response → Mobile Model → UI
```

| # | Story | Role | Use case | API |
|---|---|---|---|---|
| [US-01](view-my-depots.md) | View my depots | Sales Rep | [UC-01](../usecases/browse-depots.md) | `GET /mobile/depots` |
| [US-02](search-and-filter-depots.md) | Search and filter depots | Sales Rep | [UC-01](../usecases/browse-depots.md) | `GET /mobile/depots` |
| [US-03](view-depot-detail.md) | View depot detail | Sales Rep | [UC-02](../usecases/get-depot-detail.md) | `GET /mobile/depots/{id}` |
| [US-04](register-new-depot.md) | Register a new depot | Sales Rep | [UC-03](../usecases/create-depot.md), [UC-07](../usecases/registration-draft-lifecycle.md), [UC-08](../usecases/fetch-references.md), [UC-09](../usecases/create-business-partner.md) | several |
| [US-05](resume-registration-draft.md) | Resume an interrupted registration | Sales Rep | [UC-07](../usecases/registration-draft-lifecycle.md) | draft endpoints |
| [US-06](check-depot-code.md) | Check a depot code before registering | Sales Rep | [UC-04](../usecases/lookup-depot-by-code.md) | `GET /depots/by-code/{code}` |
| [US-07](upload-depot-documents.md) | Upload depot documents | Sales Rep | [UC-10](../usecases/manage-depot-documents.md) | `/mobile/depots/{id}/documents` |
| [US-08](work-offline.md) | Work offline | Sales Rep | [UC-05](../usecases/initial-sync.md), [UC-06](../usecases/delta-sync.md) | `GET /mobile/depots` |

## Roles

| Role | In scope on mobile |
|---|---|
| **Sales Representative** | Yes — the primary actor for every story here |
| **Sales Supervisor / Manager** | Yes — same stories, wider row-level scope |
| **HQ / Approver** (`depots.approve`) | **No** — approval is not a mobile capability, but it gates US-04's outcome |
