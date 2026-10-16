# Depot — Use Cases

Each document specifies one use case end to end: actor, flow, the exact API
request, the exact response, and the **field-by-field mapping onto the mobile
model that consumes it**.

Read [`../README.md`](../README.md) first — it holds the naming rule
(routes say `depot`, payloads say `customer`), the response envelope, the
shared business rules and the open questions.

| # | Use case | API | Mobile entry point |
|---|---|---|---|
| [UC-01](browse-depots.md) | Browse depots | `GET /mobile/depots` | `BrowseDepots` → `DepotsBloc` |
| [UC-02](get-depot-detail.md) | Get depot detail | `GET /mobile/depots/{id}` | `GetDepotById` → `DepotDetailCubit` |
| [UC-03](create-depot.md) | Create depot | `POST /mobile/depots` | `CreateDepot` → `AddDepotBloc` |
| [UC-04](lookup-depot-by-code.md) | Look up depot by code | `GET /depots/by-code/{code}` | `LookupDepotByCode` → `DepotCodeLookupCubit` |
| [UC-05](initial-sync.md) | Initial sync | `GET /mobile/depots` (paged) | `RunDepotInitialSync` → `DepotSyncCubit` |
| [UC-06](delta-sync.md) | Delta sync | `GET /mobile/depots?modifiedSince=` | `RunDepotDeltaSync` → `DepotSyncCubit` |
| [UC-07](registration-draft-lifecycle.md) | Registration draft lifecycle | 7 draft endpoints | `DepotRemoteDataSource` |
| [UC-08](fetch-references.md) | Fetch SAP reference catalogues | `GET /mobile/depots/references` | `FetchMasterData` |
| [UC-09](create-business-partner.md) | Create SAP business partner | `POST /mobile/depots/business-partner` | `CreateBusinessPartner` |
| [UC-10](manage-depot-documents.md) | Manage depot documents | `/mobile/depots/{id}/documents` | `DepotDocumentRepository` |

## Not specified here

| Use case | Why |
|---|---|
| `AddDepotNote`, `FetchDepotNotes` | Local-only today — no remote datasource exists. See [`../README.md`](../README.md) Q-06. |
| `AddDepotActivity`, `FetchDepotActivities` | Same — local-only. Q-06. |
| `ToggleFavoriteDepot`, `FetchFavoriteDepots` | Local preference, never sent to the server. |
| `FetchRecentDepots`, `RecordDepotViewed` | Local view history. |
| `GetDepotLastSyncedAt` | Reads the local sync watermark. |

These have usecases and entities in `lib/features/depots/domain/`, but no API —
they are deliberately excluded rather than invented.
