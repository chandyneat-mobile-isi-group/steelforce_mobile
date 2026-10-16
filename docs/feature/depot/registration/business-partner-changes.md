# Business Partner registration — what changed

Target endpoint: `POST {{baseUrl}}/api/v1/mobile/depots/business-partner`

## Read this first

The files from the previous hand-off had been dropped into the tree as-is, and
one of them collided. The project already had a `BusinessPartnerRepository` —
the three-call server-draft protocol (`POST /draft` → `POST /update` →
`POST /submit`). It was overwritten with a two-method interface, which left the
feature **not compiling**: `add_depot_bloc.dart` still called `openDraft()`,
`updateServerDraft()`, `submitServerDraft()`, `loadReferenceOptions()`,
`saveDraft()` and `clearDraft()`, and `depots_injection.dart` still built the
repository with two positional arguments that no longer existed.

Most of this pass was reconciling that, not adding new code.

---

## 1. Verified against your payload

All 47 keys are emitted, in the order of your Postman body, with the casing
preserved exactly — including `SALESBLOCK` and `BLOCKFLAG` in caps and
`submitToSap` in camelCase. Empty values are sent as `""` rather than omitted,
because a BAPI distinguishes "not supplied" from "supplied as blank": for the
block fields that is the difference between leaving a block alone and clearing
it.

Entity → model → JSON coverage was checked field by field; nothing is dropped
in either direction.

## 2. New files

```
data/datasources/business_partner_remote_data_source.dart   the single write
data/models/business_partner_request_model.dart             exact PascalCase toJson
data/models/business_partner_response_model.dart            tolerant fromJson + BAPI return table
data/mappers/bp_draft_to_business_partner.dart              BpDepotDraft -> request
data/local/bp_draft_cache.dart                              Hive store for the in-progress form
domain/entities/business_partner_request.dart                47-field value object
domain/entities/business_partner_result.dart                 + SapReturnMessage, SapMessageType
domain/usecases/create_business_partner.dart                 CreateBusinessPartner, ValidateBusinessPartner
presentation/bloc/business_partner_submission.dart           what AddDepotBloc calls
```

`business_partner_submission.dart` was moved out of `data/models/` — it imports
use cases, so it is presentation logic and was in the wrong layer. The duplicate
`domain/entities/create_business_partner.dart` (byte-identical to the copy in
`domain/usecases/`) was deleted.

## 3. Form fields now matching the request body

Three real gaps between the form and the payload, all closed:

**`SearchTerm2`** — the form had one search term. SAP indexes `SORT1` and
`SORT2` separately at 20 characters each, so a single longer term is truncated
and the remainder is not searchable at all. Both are now editable on the
identity step with a 20-char cap and a sub-label explaining which is which,
because "Search Term 1" does not tell a rep that it means the *place*. Both
derive when left blank: place → `SearchTerm1`, brand + district →
`SearchTerm2`, matching your sample (`PHNOM PENH` / `BAYON STEEL SENSOK`).

**`Language`** — was hard-coded `EN` on the draft and never shown, so a
Khmer-only shop was registered as an English-corresponding partner and then
sent English paperwork. Now a selector on the contact step, where your preview
screen was already listing it. Note the mapper converts it: SAP wants the
single character `E`, so `SapBpConst.defaultLanguage = 'EN'` would have been
rejected as-is.

**`DepotNumber`** and **`Region`** — added to the draft. `DepotNumber`
matters because a draft opened as a correction must keep its number or the
submit silently becomes a duplicate partner. `Region` stays defaulted to `R01`
and is not rep-visible, because SAP publishes no region catalogue this app can
read and the 25 provinces do not map onto it one-to-one — it is a field rather
than a literal so a catalogue can correct it later without touching the mapper.

The blocks (`OrderBlock`, `SALESBLOCK`, `BLOCKFLAG`) are deliberately not in
the UI. A registration never arrives pre-blocked; HQ sets a block in SAP after
the fact.

## 4. The three-call protocol is gone

`AddDepotBloc` was rewritten. `OpenServerDraft` → `OpenForm`;
`serverDraftId` and `serverFields` are deleted.

Two consequences worth stating, because they are the point of the change:

- **The form opens offline.** It used to need `POST /draft` to return an id
  before the rep could type, which failed exactly where reps work. `OpenForm`
  calls two methods that are contracted never to throw, so there is no longer a
  path where the form fails to open.
- **`Next` is instant.** It used to flush a patch and await the response, so
  advancing a step failed in a dead spot.

Resuming a half-filled form now comes from the device (`BpDraftCache`) rather
than the server, which is where it belonged: the rep who filled a form in is
the rep who finishes it.

New: a `ValidateWithSap` event runs the payload with `Commit: false`. SAP
validates and rolls back, so the rep learns about a rejected payment term while
still standing in the shop rather than from HQ the next day. Rep-triggered and
off by default — it costs a round trip and only the rep knows whether the
connection in this shop can afford one. Any subsequent edit resets the pass,
because a form that has changed since the dry run has not been validated.

## 5. `toSapPayload` was deleted, not deprecated

It emitted the old camelCase keys (`name1`, `salesOrg`, `postalCode`) for the
retired protocol. The live endpoint takes `Name1`, `SalesOrg`, `PostalCode` and
drops keys it does not recognise **without complaining** — so leaving the
method in place, even marked deprecated, meant one wrong call site produced a
registration the server accepted and SAP received almost entirely blank. The
mapping now exists in exactly one place.

Local draft persistence deliberately does *not* go through the wire shape
either: it would drop `vatTin`, the contact person, the remark and the
photographs, so a rep who resumed a saved form would silently lose the four
fields the form had just made them fill in. `toDraftJson` / `fromDraftJson`
cover the whole form instead.

---

## 6. Two decisions still open

**`PersonnelNumber` is a placeholder.** `depots_injection.dart` builds
`RepSalesContext` with `salesEmployeeId: 'mobile'`, and that value maps straight
onto `PersonnelNumber`. Every registration would reach SAP stamped `mobile`
instead of the rep's number. Marked `TODO(sales-context)` at the exact line —
it needs to come from `SessionManager` before this goes live.

**`CreditControlArea` — `0001` or `ISI`?** Your payload sample says `"0001"`.
`SapBpConst.creditControlArea` says `'ISI'`. Both cannot be right.
`SapBpWireConst.creditControlArea` currently sends `0001` on the grounds that
the payload is the newer artefact, and it lives in a separate class rather than
editing `SapBpConst`, because that constant is also read by the draft store and
changing it would rewrite the meaning of drafts already saved on devices. Same
question applies to `SapBpConst.companyCode = 'ISI'`, which this endpoint has
no field for at all.

## 7. Fields the rep fills that have nowhere to go

This endpoint has no key for `vatTin`, `faxNumber`, `remark`, or `title`. The
form validates `vatTin` as **required** when `taxClass == '1'`, so reps are
compelled to enter data that would vanish on submit.

`contactPersonName` and `contactPersonRole` now travel in `CoName` as
`Name-Role` (e.g. `Sok Dara-Owner`, see `BpDepotDraft.contactCoName`); the
rep no longer types a c/o name.

Nothing here smuggles them in as extra keys, because a middleware that does not
model them drops them without complaint and the loss is invisible. Either the
endpoint needs the fields, or they go on a second call, or the form should stop
asking. This is a product decision, not a code one.

## 8. Analyzer errors from the first drop — all fixed

The `core/` files arrived after the last pass, and five assumptions I had
flagged as unverified were wrong. All corrected:

| Assumed | Actually | Fixed in |
|---|---|---|
| `dartz` `Either` / `Left` / `Right` | **No `dartz` dependency.** `Result` with `Success(v)` / `Failed(failure)`, from `core/utils/result.dart` | repository impl |
| `.fold(onLeft, onRight)` | `.when(success:, failure:)` | submission helper |
| `ApiFailure` | Does not exist. Sealed `Failure` with `ServerFailure`, `CacheFailure`, `NetworkFailure`, `ServerUnreachableFailure`, `AuthenticationFailure` | repository impl |
| `core/errors/` | `core/error/`, **singular** | repository impl, data source |
| `ServerException.statusCode` is `String` | `int?` | data source (3 sites) |

`core/utils/result.dart` was also missing from the repository's imports —
`.when()` is an instance method so callers need no import, but the
`Success` / `Failed` constructors do.

### One thing got better as a result

`Failure` being **sealed** with a real `NetworkFailure` removed the worst part
of the original design. `_classify` was deciding whether a failed submit could
be safely retried by substring-matching the error message
(`lower.contains('no connection')`). That is one copy edit away from turning one
shop into two partners.

It now switches on the failure type, and the data source throws typed
exceptions to feed it:

- `connectionError` / `connectionTimeout` / `sendTimeout` → `NetworkException`
  → `NetworkFailure` → **nothing was sent**, safe to hold and resend.
- `receiveTimeout` → `ServerException(statusCode: 504)` → **sent, no answer**,
  so the write may have landed; flagged `mayHaveLanded: true` and must not be
  blind-retried.
- other 5xx → gateway failed before SAP, nothing committed.
- 4xx → a real rejection the rep can act on.

The switch is exhaustive over all five `Failure` variants, so a new one added
to `core/error/` becomes a compile error here rather than a silent
misclassification.

## 8b. Five test files still need migrating

These were not in the zip, so I could not edit them. Each break is a rename,
not a behaviour change:

**`bp_address_geo_integration_test.dart`** (7 sites) and
**`depot_form_address_test.dart`** (1 site) — call `toSapPayload`, which was
deleted. Replace with the mapper, and note **the assertion keys change from
camelCase to PascalCase**:

```dart
// before
final payload = draft.toSapPayload(rep);
expect(payload['street'], 'Street 1986, Phum X, Sangkat Y');

// after
final payload = draft.toBusinessPartnerRequest(rep: rep).toJson();
expect(payload['Street'], 'Street 1986, Phum X, Sangkat Y');
```

The street-line folding these tests guard (`sapStreetLine`, commune/village
into `Street`) is unchanged, so the expected *values* stay as they are.

**`depot_draft_resume_test.dart`** and
**`depot_references_live_payload_test.dart`** — construct
`BusinessPartnerRepositoryImpl` positionally and call `openDraft()`. The
constructor is now four named arguments, and `openDraft` is gone:

```dart
BusinessPartnerRepositoryImpl(
  remote: mockBpRemote,          // BusinessPartnerRemoteDataSource
  references: mockLegacyRemote,  // legacy.DepotRemoteDataSource
  referenceCache: referenceCache,
  draftCache: draftCache,        // BpDraftCache
)
```

`openDraft()` → `loadDraft()`, which returns `BpDepotDraft?` from the device
instead of `OpenedRegistrationDraft` from the server. The resume assertions
still apply; they just read the draft directly rather than `.draft` /
`.resumed`.

**`add_depot_evidence_test.dart`** — `AddDepotBloc` now needs
`submission:`, `OpenServerDraft` is `OpenForm`, and the mock's
`openDraft` / `updateServerDraft` / `submitServerDraft` stubs should become
`loadDraft` / `loadReferenceOptions` plus a stubbed `BusinessPartnerSubmission`.
`BusinessPartnerSubmitResult` is now `BusinessPartnerResult`
(`depotNumber`, `isCreated`, `messages`).

The evidence-upload behaviour this file covers is untouched — `_uploadEvidence`
was carried over unchanged, including the "never throw, a depot is never
lost to a photograph" contract.

## 8c. Pre-existing, not from this work

Two analyzer errors in the report are unrelated and were already there:
`lib/features/order/presentation/screens/quotation/promotion_section.dart.dart`
has a doubled `.dart` extension and imports a `promotion_detail_screen.dart.dart`
that does not exist; and `_QuickAccessRow` in `depots_screen.dart` is unused.

## 8d. The first live run: 200 OK reported as a failure

```
↑ BP     POST commit  sales_area=0002/10/10 existing=create
api.response status=200 ms=10773
✗ BP     accepted but no depot number
! SUBMIT held
```

The server accepted the registration. My code called it a failure. Two
separate bugs:

**The parser looked for the wrong keys.** This endpoint answers with
`{depotCode, sapStatus, depotId}` — which `CreateBpResponse` in
`data/remote/depot_datasources.dart` has been parsing on this exact route
all along. My model only looked for `DepotNumber` / `depotNumber` /
`KUNNR`, found nothing, and returned an empty result. Those keys are now read,
along with `depotId` and `sapStatus`.

**A missing depot number is not an error.** `depotCode` is null while HQ
approval is pending — the record is stored and will be pushed to SAP once
approved. My repository required a number and failed the submit without one, so
**every pending registration was reported as failed**. A rep who believes the
submit failed re-enters the shop, and HQ receives a duplicate.

The check is now `isAccepted` — did the server give us *any* handle on the
record (`depotId`, `depotCode`, or a non-rejected `sapStatus`) — rather
than "is there a SAP number". `BpSubmissionStatus` models the lifecycle, and an
unrecognised status is treated as accepted, because the server is the authority
on its own states and can add one before this app ships again.

**Third, smaller bug, visible as `held`.** The 502 I was synthesising for "no
depot number" was then classified downstream as a 5xx gateway failure and
reported to the rep as held-and-will-retry. There is no retry worker, and the
record may well have existed. That verdict is now a 422, so it reads as a
rejection with an actionable message, and the log carries the field names
actually received so a shape change is diagnosable from one line.

**Fourth: evidence was being filed against the wrong id.** `_uploadEvidence`
was passed `depotNumber`, which is empty for a pending record — so it took
the "no server depot id yet" branch and held every photograph on the device.
It now receives `documentId`, which prefers the platform's `depotId` and
exists as soon as the record is stored.

The success message now distinguishes the two outcomes. "Sent for approval" and
"depot 0000123456 created" are different promises, and showing the second
when the first is true is how a rep comes to believe they can order against the
shop today — and gets refused in front of the depot.

### The second log was the same build

A later run showed the identical line:

```
✗ BP     accepted but no depot number
! SUBMIT held
```

That string no longer exists in the source — the current code emits
`response carried no usable record`. So that run was the pre-fix build, and the
fixes above were not in it. Rebuild before reading anything more into the log.

### Diagnostics added so this stops being guesswork

The response key names have now been guessed at twice. Rather than a third
round, the data source prints them when the parse finds no handle on the
record:

```
! HTTP    response not understood  top=[...] parsed=[...] status_field=unknown
```

`top` is the raw body's keys, `parsed` is what survived envelope unwrapping.
Field **names only, never values** — `DebugTrace` is debug-only and this
endpoint carries depot PII. One line from the next run settles the shape.

The outgoing payload is also checked against the documented 47 fields and warns
if the count has drifted, since the server drops keys it does not recognise
without complaining — an incomplete body reaches SAP looking valid.

### Worth checking on the next run

`sales_area=0002/10/10` — sales org `0002` is *Building Solutions* while
`SalesOffice` falls back to the rep's session value. Worth confirming that
pairing is one SAP accepts for this shop; the dry run (`ValidateWithSap`) will
answer it without creating anything.

The call took **10.8 seconds**. That is inside the 60s write timeout on
purpose, but it is long enough that a rep on a worse connection will hit the
receive timeout, and that path is the one flagged `mayHaveLanded: true`.

### One inconsistency inside the sample payload itself

The sample pairs `"DepotGroup": "01"` (End-User) with `"PriceGroup": "21"`,
but `21` is *Local Builder* — `01` pairs with `11` in
`priceGroupByDepotGroup` and in the ERP catalogues matched by name. The app
derives `PriceGroup` from `DepotGroup`, so it will send `11` here, not `21`.

If `21` in the sample is deliberate, the derivation rule is wrong; if it was
hand-written for a Postman test, the app is right. Worth one question to the
SAP team, since a price group the ERP rejects fails the whole push.

## 8e. Field-by-field diff against the reference body

The body was verified against the reference payload rather than assumed
correct: 47 keys, no extras, no omissions, same order. Four **values** differed.

| Field | Reference | App was sending | Resolution |
|---|---|---|---|
| `PersonnelNumber` | `100389` | **`mobile`** | Fixed — see below |
| `Latitude` | `11.5680` | `11.568000` | Now 4 dp, matching the contract |
| `Longitude` | `104.8920` | `104.892000` | Now 4 dp |
| `PriceGroup` | `21` | `11` | Made overridable — unresolved, see below |

### `PersonnelNumber: "mobile"` — this is the "not stored in SAP" bug

SAP's `PERNR` is a **numeric** field. The placeholder `RepSalesContext` in
`depots_injection.dart` supplied the literal string `'mobile'`, so every
registration carried a personnel number that cannot exist. The middleware
accepts the record and answers 200; the SAP push then fails on it. The result
is a registration that exists on the backend and never in the ERP — which is
exactly the reported symptom, and nothing in the mobile log pointed at it
because from the app's side the call succeeded.

Three changes:

- The mapper strips non-digits from `salesEmployeeId`, so a stray label can
  never again be sent as a personnel number.
- If nothing numeric remains, `missingForRegistration` names
  `PersonnelNumber` and the submit is refused before the request goes out.
  Refusing is better than sending: a visible error beats a record that
  silently never reaches SAP.
- The DI fallback is now `100389` — the reference payload's number — so
  registrations land against a real personnel record. **It is wrong for every
  rep who is not that person** and must not survive to release; the
  `TODO(sales-context)` is on it.

### Coordinates now match the contract

Four decimal places, not six. Six is genuinely better — four is about 11 metres
and does not reliably separate one shopfront from its neighbour — but the
documented body sends four, the SAP geo fields have a fixed width, and a string
wider than the field accepts is precisely the class of difference that gets a
record accepted by the middleware and dropped on the push. If the field turns
out to be `CHAR(11)` or wider, raise it back to 6; nothing else depends on it.

### `PriceGroup` is still genuinely ambiguous

The reference payload pairs `DepotGroup: "01"` (End-User) with
`PriceGroup: "21"`. Both `priceGroupByDepotGroup` and the name-matched ERP
catalogues pair `01` with `11` — `21` is *Local Builder*. One of the two is
wrong and it is not decidable from the app.

Rather than guess, the field is now a visible, overridable dropdown on the
sales-terms step (it was display-only before). The derived value still fills it
in; a manual pick sets `priceGroupOverridden` so re-derivation on the next edit
does not clobber it. That way either value can be tested against SAP without a
rebuild, and a rep who can see a wrong price group can correct it — a wrong one
fails the entire push.

## 8f. Partner Grouping now comes from `GET /references`

The Grouping dropdown on the identity step read the hard-coded
`SapMasterData.grouping` (3 entries). It now reads the ERP's `PartnerGroup`
catalogue via `SapReferenceOptions.partnerGroup`, with the built-in list kept
as the offline fallback.

**The catalogue is filtered, and that is the point.** `GET /references` returns
the whole BP grouping table — 11 entries:

| Shown | Filtered out |
|---|---|
| `Z001` Local Depot | `ZBP1` Local Supplier |
| `Z002` Export Depot | `ZBP2` Overseas Supplier |
| `Z003` Group Member | `ZSL1`/`ZSL2` Term Loan |
| | `ZSL3` Other Liability |
| | `ZSL4` Employee |
| | `ZSL5` Loan Receivable |
| | `ZSP3` Time Supplier |

Grouping is sent as **both** `PartnerGroup` and `AccountGroup`, and this form
creates `BpRole: ZFLCU1` (Depot). Offering the other eight would let a rep
register a steel shop as a term loan or an employee; SAP would reject the push,
and the rep could not tell that from any other rejection.

The filter matches on the known depot codes **or** the word "depot" in
the ERP's own name, so `Z004 Project Depot` added in SAP later appears with
no app release, while `ZBP3 New Supplier` stays out. If the filter ever matches
nothing — the catalogue reorganised in a way this build does not understand —
it falls back to the built-in list rather than rendering an empty dropdown,
which would block registration outright.

`allPartnerGroups` exposes the unfiltered catalogue for any screen that is not
depot registration.

### One label was wrong offline

The built-in list called `Z003` **"One-time Depot"**; the ERP calls it
**"Group Member"** (an intercompany depot). The fallback now uses the ERP's
wording, so the same code is named the same way online and off — a rep who
picks `Z003` offline and sees it renamed after a sync has no way to tell
whether the meaning of their registration changed.

## 8g. `?includeInactive=true` on `GET /references`

Supported, and **off by default for the registration form** — which is the
whole decision here.

Per the endpoint's own description the parameter returns "active AND retired
codes". A retired code renders in a dropdown identically to a live one, so a
rep offered one has no way to know, picks it, and the SAP push is rejected with
nothing on screen to explain why. That is the same failure shape as the
`PersonnelNumber: 'mobile'` bug: valid-looking input, accepted locally, lost at
the ERP boundary.

Where it *is* needed is reading existing records. A depot registered two
years ago may hold a payment term SAP has since retired; without the retired
codes the detail screen can only show the raw code, or nothing. So the
parameter is plumbed through and available — it is just not what the form asks
for.

```dart
// Registration form — live codes only (the default).
await repository.loadReferenceOptions();

// Naming a stored code on an existing record.
await repository.loadReferenceOptions(includeInactive: true);
```

### The two responses are cached separately

`DepotReferenceCache` now keys on the variant: `sap_depot_references` for
active-only and `sap_depot_references:all` for the full set.

Sharing one key would have made screen order decide correctness — open a
depot's detail page first, and the registration form would then serve
retired codes out of the cache the detail page had filled. A rejected push
caused by nothing but the order the rep tapped through the app is the kind of
bug that never reproduces on request.

`clear()` drops both variants; leaving one would resurrect the other screen's
copy. The active-only key is byte-identical to the previous single key, so
caches already on devices keep working and no migration is needed.

`includeInactive` is omitted from the query string when false rather than sent
as `false`, leaving the server on its own default instead of this client
asserting one.

## 9. Tests worth adding

`features/depots/` has 7 test files. The mapper is the piece most worth a
new one — it is pure, and a wrong `SalesOrg` is not a crash but a depot
routed to the wrong office:

- `salesOrg` set → payload uses it, not `rep.salesOrganization`
- `salesOrg` null → falls back to the session value
- `language: 'EN'` → `"Language": "E"`
- `depotGroup: '08'` → `"PriceGroup": ""`, not an invented code
- no GPS fix → `Latitude`/`Longitude` are `""`, not `"null"`
- a draft with a `depotNumber` → survives submit and is not blanked
- `toJson()` emits all 47 keys including the empty ones
- round-trip `toDraftJson` → `fromDraftJson` preserves photos and `vatTin`

And for the response, against the shape the live run revealed:

- `{depotCode: null, sapStatus: 'PENDING_HQ', depotId: 'abc'}` →
  `isAccepted` true, `isPendingApproval` true, **not** a failure
- `{depotCode: '0000123456', sapStatus: 'CREATED'}` → `isCreated` true
- `{sapStatus: 'REJECTED'}` → `hasError` true
- an empty body → `isAccepted` false, and `receivedKeys` is populated
- a pending result → `documentId` returns `depotId`, not `''`

And for the grouping catalogue:

- the 11-entry `PartnerGroup` payload → exactly `Z001`, `Z002`, `Z003` offered
- a catalogue containing `Z004 Project Depot` → four options, not three
- a catalogue of suppliers only → falls back to the built-in list, never empty
- no catalogue loaded → the three built-in options

And for the inactive-codes flag:

- `loadReferenceOptions()` → no `includeInactive` key in the query string
- `loadReferenceOptions(includeInactive: true)` → `includeInactive=true` sent
- fetching both variants → two cache entries, neither overwriting the other
- a cache written by the previous build → still read by the active-only path
- `clear()` → both variants gone
