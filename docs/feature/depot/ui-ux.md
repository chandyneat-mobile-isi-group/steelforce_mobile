# Add Depot (SAP BP) — Mobile Step & Section Design

**Scope:** Sales rep creates a Business Partner from the phone.
**SAP path:** Create Organization (BP) → Extend Depot → FI Depot, BP role `ZFLCU1`.
**Source:** `docs/feature/depot/reference/bp-creation-fields-sap.xlsx`
**Current implementation:** `add_depot_bottom_sheet.dart` (3 steps — Shop Details / Contact Person / Location & Papers)

---

## 1. The design problem

The SAP sheet lists ~60 fields. If we put them all on a phone the rep will abandon the form.
So every field is assigned an **owner** before it is assigned a step:

| Owner | Meaning | Count | Shown to rep? |
|---|---|---|---|
| **REP** | Rep types or picks it | 22 | Yes — this is the whole form |
| **CONST** | Hard-coded at frontend (the sheet already says "hard code at frontend") | 9 | No |
| **DERIVE** | Computed from GPS, the rep's session, or another field | 8 | Read-only chip, greyed |
| **SAP** | Comes back from SAP after HQ approval (`SAP - SF` in the sheet) | 20+ | Detail screen only, never in the creation flow |

**Only the 22 REP fields belong in the stepper.** Everything else is payload or read-back.

---

## 2. Step structure (5 steps, replacing the current 3)

```
Step 1  Depot Identity      7 fields  (2 required)   ~20s
Step 2  Address & Location     7 fields  (4 required)   ~40s  ← GPS blocking
Step 3  Contact                6 fields  (3 required)   ~25s
Step 4  Sales & Billing Terms  9 fields  (all defaulted) ~15s if defaults accepted
Step 5  Documents & Review     4 photos  (3 required)   ~60s
```

Keep the existing responsive behaviour: `_stepColumns > 1` on tablet renders all steps side by side, phone renders one step at a time. With 5 steps the tablet grid becomes `Wrap` at 2–3 columns, which the current `_buildAllStepsBody()` already handles.

---

### Step 1 — Depot Identity
> *"Who is this depot?"* — BP header + Address ▸ Name

| # | Label (EN / KH) | SAP field | Widget | Req | Notes |
|---|---|---|---|---|---|
| 1 | Depot Type / ប្រភេទអតិថិជន | Grouping | Dropdown | ✅ | Default `Z001 - Local Depot`. Also drives Account Group. |
| 2 | Title / ងារ | Title | Dropdown | ✅ | Default `0003 - Company` |
| 3 | Depot Name (EN) | Name 1 | Text, 40 char cap | ✅ | SAP `NAME1` is 40 chars — enforce `maxLength: 40` |
| 4 | Depot Name (KH) | Name 3 | Text, Khmer keyboard | ✅ | Validate it actually contains Khmer unicode `\u1780-\u17FF` |
| 5 | Trading / Legal Name | Name 2 | Text | ⬜ | Collapsed under "More details" |
| 6 | Search Term | Search Name 1/2 | Text | ⬜ | Auto-suggest = first word of Name (EN), uppercased |
| 7 | c/o Name | CO-Name | Text | ⬜ | Collapsed under "More details" |

**Hidden CONST sent with this step:** `Partner Category = 2`, `BP Role = ZFLCU1`, `Account Group = Grouping`.

> ⚠️ **Remove the Depot Code field.** The current form has `_depotCodeCtrl` as a required rep input. SAP assigns the depot number from the `Z001` number range — a rep-typed code will collide or be discarded. Replace it with a read-only "Assigned after approval" chip and show the real code on the detail screen once `BpSapEcho.depotCode` arrives.

---

### Step 2 — Address & Location
> *"Where are they?"* — Address ▸ Standard Address

| # | Label | SAP field | Widget | Req | Notes |
|---|---|---|---|---|---|
| 1 | Street | Street | Text | ⬜ | |
| 2 | House No. | House Number | Text (numeric) | ⬜ | Same row as Street, 60/40 split |
| 3 | City / Province | City | Dropdown (code) | ✅ | **Must be a code** (`12 - Phnom Penh`), not free text |
| 4 | District / Khan | District | Dropdown, dependent on City | ✅ | Sheet marks it "No" but flags it "Create" — make it required, HQ needs it for routing |
| 5 | Postal Code | Postal Code | Text, 5 digits | ✅ | Auto-filled from District, still editable |
| 6 | Country | Country | Locked chip `KH - Cambodia` | ✅ | CONST |
| 7 | **GPS Location** | Latitude / Longitude | Capture tile + mini map | ✅ | See below |
| 8 | Language | Language | Dropdown | ⬜ | Default `EN`, collapsed |

**DERIVE (shown as grey chips, not inputs):** `Region = R01 - Central Area`, `Time zone = UTC+7`.

**GPS rules — this is the one field that can't be faked later:**
- Capture must happen **on site**; block a fix older than 5 minutes.
- Reject a fix outside the Cambodia bounding box (`lat 9.9–14.7`, `lng 102.3–107.7`) — catches emulator/stale last-known coords.
- Reject accuracy > 100 m, offer "Retry".
- Store `accuracy` and `captured_at` alongside lat/long so HQ can audit.
- Show the captured point on a small static map so the rep sees an obviously wrong pin.

> The current code stores `_gpsCoords` at 5 decimals for display but sends the display string. Send the raw doubles (`_latitude`, `_longitude`) at full precision — the sheet's sample is `11.531871600000001`, i.e. SAP keeps full precision.

---

### Step 3 — Contact
> *"How do we reach them?"* — Address ▸ Communication

| # | Label | SAP field | Widget | Req | Notes |
|---|---|---|---|---|---|
| 1 | Mobile Phone | Mobile Phone | `PhoneFormField` (KH) | ✅ | Already implemented — keep |
| 2 | Telephone | Telephone | `PhoneFormField` + "Same as mobile" switch | ✅ | SAP marks both mandatory; the switch avoids double typing (default ON) |
| 3 | Fax | Fax Number | Text | ⬜ | Collapsed |
| 4 | Contact Person Name | *(BP contact person)* | Text | ✅ | App-side CRM data |
| 5 | Role | *(BP contact person)* | Dropdown | ✅ | Owner / Manager / Buyer / Accountant |
| 6 | Owner Name | *(maps to Name 2 or contact)* | Text | ⬜ | Decide with HQ — currently `_ownerNameCtrl` has no SAP target |

> **Open item:** `Owner Name` in the current form has no SAP field in the sheet. Either map it to `Name 2` or drop it into Additional Data. Don't ship it un-mapped.

---

### Step 4 — Sales & Billing Terms
> *"How do we sell to them?"* — Sales Area + Orders + Shipping + Billing

This is where reps drown. Render it as **one summary card of applied defaults with an "Adjust" expander**, so the default path is a single tap.

**Always visible (4 fields):**

| # | Label | SAP field | Widget | Req | Default |
|---|---|---|---|---|---|
| 1 | Depot Group | Depot Group | Dropdown | ✅ | *(replaces "Shop Type")* |
| 2 | Payment Term | Payment Term | Dropdown | ✅ | `T00 - Cash` |
| 3 | Tax Class | Tax Class | Segmented (Non-VAT / VAT) | ✅ | `0 - Non VAT` |
| 4 | VAT TIN | *(Depot Tax Data)* | Text | ⚠️ | Only when Tax Class = VAT |

**Inside "Adjust" (5 fields):**

| # | Label | SAP field | Default |
|---|---|---|---|
| 5 | Distribution Channel | Distribution Channel | `10 - End User` |
| 6 | Division | Division | `10 - ISI Steel` |
| 7 | Delivery Priority | Delivery Priority | `01 - High` |
| 8 | Shipping Condition | Shipping Condition | `01 - ISI Service` |
| 9 | Currency | Currency | `USD` |

**DERIVE chips (read-only):** Sales Organization, Sales Office and Sales Employee come from the logged-in rep's session (`RepSalesContext`). Price Group is derived 1:1 from Depot Group.

**CONST (hidden):** Sales Group `010`, Depot Pricing Procedure `1`, Departure Country `KH`, Tax Category `MWST`, Credit Control Area `ISI`, Partner Function `VE`.

> **Credit gate:** any Payment Term other than `T00 - Cash` is a credit sale. Show the existing amber `credit_notice` banner *here* (not on the photos step, where it currently sits) and label the submit button "Send to HQ for credit approval". This is what the sheet's `Credit Segment Data → Limit Defined` block is for — HQ sets the limit, the app only reads it back.

---

### Step 5 — Documents & Review
> *"Prove it, then send."*

**Photos** (camera-only, no gallery picker — the point is on-site evidence):

| Photo | Req | Notes |
|---|---|---|
| Outlet — Front | ✅ | Signboard must be readable |
| Outlet — Inside | ✅ | |
| Owner ID card | ✅ | |
| Patent Tax certificate | ⬜ | |
| VAT certificate | ⚠️ | Required only when Tax Class = VAT |

**Then a review summary** — a collapsed recap of steps 1–4 with an edit pencil per section, so the rep can fix a typo without walking back through the stepper.

**Then submit.** After submit the record is `PENDING_HQ`, read-only, and the rep sees a status timeline: `Submitted → HQ Review → Credit Check → Created in SAP (code assigned)`.

> The current implementation fakes attachments (`setState(() => _outletPhotoFront = "front_outlet.jpg")`). Wire this to a real camera + compress to ≤ 1600 px / ~300 KB before queueing — reps work on 3G.

---

## 3. Full field mapping (SAP sheet → mobile)

### Rep-entered (22)
Grouping · Title · Name 1 (EN) · Name 2 · Name 3 (KH) · Search Term · CO-Name · Street · House Number · District · Postal Code · City · Latitude · Longitude · Telephone · Mobile Phone · Fax · Language · Distribution Channel · Division · Depot Group · Delivery Priority · Shipping Condition · Payment Term · Tax Class

### Hard-coded at frontend (matches the sheet's own "hard code at frontend" note)
`Partner Category = 2` · `BP Role = ZFLCU1` · `Region = R01` · `Sales Group = 010` · `Depot Pricing Procedure = 1` · `Departure Country = KH` · `Tax Category = MWST` · `Partner Function = VE` · `Country = KH` · `Time zone = UTC+7`

### Derived
`Account Group` ← Grouping · `Price Group` ← Depot Group · `Postal Code` ← District · `Search Term` ← Name 1 · `Sales Organization`, `Sales Office`, `Sales Employee`, `Currency` ← rep session

### Read-back only (`SAP - SF`, never editable in app)
Depot Code · Reconciliation Account · Company Code · FI Payment Term · Credit Limit Defined · Credit Changed On · Sales Order Block · Block Sales Support · Deletion Flag · Created by/on · Last changed by/on · Bank Key · Bank Account · Account Holder · Account Name · Finance Institution

> Note the bank block (`Payment Transactions`) is marked `SAP - SF` in the sheet — it flows **into** the app, so the rep must not be asked for bank details during creation.

---

## 4. Gaps in the current `add_depot_bottom_sheet.dart`

| # | Issue | Fix |
|---|---|---|
| 1 | `_depotCodeCtrl` — rep types the SAP code | Remove; SAP number range assigns it |
| 2 | `_cityCtrl` is free text | Must be a `SapOption` dropdown carrying the code |
| 3 | No District / Postal Code fields | Add to Step 2, both required |
| 4 | No Title / Grouping | Add to Step 1 |
| 5 | Shop Type (`Retailer/Wholesaler/…`) has no SAP target | Rename to **Depot Group** with real SAP codes `01–05` |
| 6 | Only one phone; SAP needs Telephone **and** Mobile | Add Telephone + "same as mobile" switch |
| 7 | Whole Sales & Billing block missing | New Step 4 |
| 8 | GPS sent as a display string, 5 dp | Send raw doubles + accuracy + timestamp |
| 9 | GPS not validated | Add Cambodia bbox + accuracy + freshness checks |
| 10 | Photos are stubbed strings | Wire camera, compress, upload queue |
| 11 | Bloc events (`UpdateShopDetails` etc.) have fixed params | Replace with a single `UpdateDraft(BpDepotDraft)` event |
| 12 | Credit banner sits on the photos step | Move to Step 4, next to Payment Term |
| 13 | Hardcoded English labels (`'Outlet Name (KH)'`, `'Phone Number'`) | Move to `.tr` keys like the rest of the file |

---

## 5. Code

`bp_depot_form_data.dart` (attached) is pure Dart — steps enum, SAP constants, master data, per-step validation, and `toSapPayload()` shaped to mirror the SAP structure so the middleware maps 1:1.

### Wiring it into the existing sheet

```dart
// 1. Replace the enum
enum DepotFormStep { identity, address, contact, salesTerms, documents }

// 2. One draft instead of scattered controllers/flags
final _draft = BpDepotDraft();
late final RepSalesContext _rep = sl<SessionService>().salesContext;

// 3. Step router — same shape as the current _buildStepBody switch
Widget _buildStepBody(BpFormStep step) => switch (step) {
      BpFormStep.identity   => _buildIdentityStep(),
      BpFormStep.address    => _buildAddressStep(),
      BpFormStep.contact    => _buildContactStep(),
      BpFormStep.salesTerms => _buildSalesTermsStep(),
      BpFormStep.documents  => _buildDocumentsStep(),
    };

// 4. Gate "Next" on the model, not on a GlobalKey<FormState>
final errors = _draft.validateStep(state.currentStep);
if (errors.isEmpty) bloc.add(NextStep()); else setState(() => _errors = errors);

// 5. Submit
bloc.add(SubmitToHQ(_draft.toSapPayload(_rep)));
```

`_buildInputLabel`, `_buildTextField`, `_buildDropdownField`, `_buildPhoneField` and `_buildActionTriggerTile` are reused unchanged — `_buildDropdownField` just takes `{for (final o in SapMasterData.city) o.code: o.display}`.

### Step indicator

`_buildFormHeader` currently hardcodes `'{total}' → '3'`. Change to `'${BpFormStep.values.length}'` and drive `stepNumber` off `state.currentStep.number`.

---

## 6. Offline behaviour

Reps create depots in the field, often with no signal:

- Persist the draft to local DB on every step transition; resume on app restart.
- Queue submission; retry with exponential backoff.
- Photos upload separately from the JSON — submit the record first, attach photos as they upload, and show per-photo progress.
- Never let an unsynced draft look "Created" — status chips: `Draft → Queued → Submitted → Pending HQ → Active`.

---

## 7. Open questions for HQ / SAP team

1. Is `District` really optional? The sheet says Mandatory = No but Attribute = Create.
2. Does `Owner Name` map to `Name 2`, or to a BP contact person, or to Additional Data?
3. Is `Sales Employee` (listed twice in the sheet) two partner functions, or a duplicate row?
4. Which `Delivery Plant` should default — the sheet leaves it blank.
5. Can the rep choose Payment Term at all, or is every new depot forced to `T00 - Cash` until HQ sets a credit limit?
6. What is the full City code list and the District list per city? The Dart file ships a Phnom Penh sample only.
