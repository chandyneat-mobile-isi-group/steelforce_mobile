# Depot Mobile Registration — Implementation

---

## Files added

### Domain — `src/ISI.Domain/Modules/Depots/`

| File | Contents |
|---|---|
| `DepotReference.cs` | The reference row + `DepotReferenceKind` (10 members) |
| `DepotDraft.cs` | The draft aggregate, `DepotDraftStatus`, `DepotDraftFields` (46) |

### Application — `src/ISI.Application/Features/Depots/`

| File | Contents |
|---|---|
| `Reference/SyncDepotReferencesFromSapCommand.cs` | The sync + its scheduled wrapper |
| `Reference/GetDepotReferencesQuery.cs` | DB-first read, search, bulk exclusion |
| `Registration/DepotDraftCommands.cs` | Start, update, submit, get, list, discard |
| `Registration/DepotDraftFieldMapping.cs` | Wire ↔ domain, generated so they cannot drift |

`Abstractions/Infrastructure/SapDepotHelperDto.cs` — the ten verified catalogue shapes.

### Contracts / Persistence / Infrastructure

`DepotReferenceContracts.cs`, `DepotDraftContracts.cs`,
`DepotReferenceConfiguration.cs` (both tables), `SapDepotDefaultsOptions.cs`,
`DepotDraftDefaults.cs`, migration `20260826082643_AddDepotReferencesAndDrafts`.

### Tests

`tests/.../Features/DepotRegistration/DepotDraftTests.cs` — 15 tests.

---

## Files modified

| File | Change |
|---|---|
| `MobileDepotsController.cs` | 7 registration actions |
| `DepotSapController.cs` | `POST sap/sync-references` |
| `ISapDepotService.cs` / `SapDepotService.cs` | `GetDepotReferencesAsync` |
| `DepotErrors.cs` | 7 error members |
| `DepotDtos.cs` / `DepotMobileMapping.cs` | **`sapStatus` on the mobile summary and detail** |
| `docs/feature/depot/api-design-notes.md` | Registration endpoints, new section, `sapStatus` change |
| `IApplicationDbContext.cs` / `ApplicationDbContext.cs` | Two new sets |
| `BackgroundJobs/DependencyInjection.cs` | Daily `sap-depot-reference-sync` at 03:00 UTC |
| `Infrastructure/DependencyInjection.cs` | Defaults options + adapter |
| `LocalizationService.cs` | 6 message keys, English + Khmer |

No new project, no new package, no `Dockerfile` change.

---

## Database

```
depot_references
  id, kind, code, name, synchronised_at, + audit/soft-delete/version
  ix_depot_references_key  UNIQUE (kind, code)

depot_drafts
  id, owner_user_id, status, submitted_depot_id, submitted_at,
  46 SAP business-partner columns, + audit/soft-delete/version
  ix_depot_drafts_owner_status        (owner_user_id, status)
  ix_depot_drafts_submitted_depot  (submitted_depot_id) WHERE NOT NULL
```

`depots` was not touched. Seeded on first sync: **5,918 reference rows**.

---

## Configuration

```
SAP__DepotDefaults__PartnerCategory=2      # organisation
SAP__DepotDefaults__Country=KH
SAP__DepotDefaults__Language=E
SAP__DepotDefaults__Currency=USD
SAP__DepotDefaults__TaxCountry=KH
SAP__DepotDefaults__AccountGroup=          # set per environment
SAP__DepotDefaults__BpRole=
SAP__DepotDefaults__SalesOrg=
# …and the rest of the sales area, all optional
```

Every value optional — a blank one leaves that field empty on the form. Nothing is
validated on start, so an environment that has not configured these still works.

---

## Verification

### Build and tests

```
dotnet build ISI.Platform.slnx  → 0 warnings, 0 errors (warnings are errors here)
dotnet test  ISI.Platform.slnx  → 192 passed, 0 failed   (15 new)
```

One of the new tests caught a real bug before it shipped: the patch used
`?? current`, which cannot express "set this back to nothing", so clearing a field
stored `""` instead of null — and SAP would have received it. Fixed with an explicit
three-way patch helper.

### Live, against the real SAP connection

| Check | Result |
|---|---|
| Reference sync | **5,918 rows across all 10 catalogues in 3.8 s**, 0 failed |
| Form-open payload | 9 catalogues, 109 rows, **4.5 KB in 98 ms** |
| Sales-employee search | `search=leng` → 48 matches, 2.3 KB, 39 ms |
| Draft open | 8 of 46 fields prefilled, 137 ms |
| Three sequential patches | 105 / 14 / 8 ms; defaults preserved, `bl30` → `BL30`, Khmer intact |
| Submit | `BP-202608-00003`, `sapStatus: Submitted`, 217 ms |
| Mobile list | Shows `status=Draft sapStatus=Submitted` |
| Mobile detail | Carries `sapStatus` too, so tapping through does not lose it |
| Re-submit | 409 `Depot.DraftAlreadySubmitted` |
| Update after submit | 409 `Depot.DraftNotEditable` |
| Submit empty draft | 400 with all four missing fields at once |
| Another rep's draft | 404 |
| OpenAPI | All 7 in `v1.json` and `mobile.json`; admin sync in `admin.json` |

---

## Known limitations

1. **`DayLimit` from `GetPaymentTerm` is read but not stored.** The platform already
   models credit terms in days on the depot; mapping it onto `CreditTermDays` is the
   obvious next step and was out of scope here.
2. **No dependency chain between dropdowns.** The API exposes none — each endpoint
   filters only by its own id. See [`docs/feature/depot/registration/sap-helpers.md`](sap-helpers.md).
3. **The middleware is intermittently slow.** Under sync load three catalogues timed
   out at 280–400 s. Handled (partial success, additive import) but worth watching.
4. **Drafts are never expired.** An abandoned form stays in `depot_drafts`
   indefinitely. A cleanup job for drafts untouched for, say, 90 days is the natural
   follow-up.
5. **The commercial status stays `Draft` after submission.** That is deliberate —
   `Draft`/`PendingApproval` is the credit-approval workflow and is a different question
   from SAP registration. `sapStatus` is what moves, and the mobile list now shows it.
No deployment permission step is needed. Unlike `materials.read`, which was added in
this release, `depots.create` and `depots.read` are pre-existing permissions and
are already granted — verified on the dev database:

| Permission | Roles holding it |
|---|---|
| `depots.create` | Administrator, Sales Manager, Sales Representative, Supervisor |
| `depots.read` | + Executive, Finance, Warehouse |
| `depots.sync` | Administrator, Finance, Sales Manager |

So a Sales Representative can use the whole registration flow the moment it deploys.
