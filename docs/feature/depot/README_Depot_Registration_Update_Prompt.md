# SteelForce Flutter --- Depot Registration Feature Update Prompt

Use this document as the implementation prompt for updating the
**existing Depot Registration / Depot Draft feature** in the SteelForce
Flutter mobile application. The goal is to align the current entities,
models, API services, state management, validation, attachments, and UI
with the backend contract below.

> **Important:** Treat the existing repository as the source of truth
> for architecture and naming conventions. Inspect the current code
> before changing it. Reuse established patterns and avoid creating a
> parallel implementation.

------------------------------------------------------------------------

## 1. Role and Objective

Act as a senior Flutter engineer working on the SteelForce mobile app.

Update the current Depot Registration feature so it correctly supports
creating and editing depot drafts through the backend API, selecting
SAP/reference values, managing depot contacts and sales areas, capturing
GPS location, and uploading/viewing evidence attachments.

The implementation must be production-minded, maintainable, testable,
and consistent with the project's existing architecture and UI design.

### Main objectives

1.  Audit the existing Depot Registration feature and identify all
    relevant screens, entities, DTOs/models, repositories,
    providers/blocs/controllers, API clients, routes, validators, and
    tests.
2.  Update or add models that match the backend request and response
    contracts.
3.  Integrate `POST /api/v1/depot-drafts`.
4.  Integrate depot reference data from `GET /api/v1/depots/references`.
5.  Integrate attachment upload and retrieval:
    -   `POST /api/v1/depot-drafts/{id}/attachments`
    -   `GET /api/v1/depot-drafts/{id}/attachments`
6.  Connect all form controls to real state and API data. Do not leave
    important controls as mock-only, decorative, or disconnected UI.
7.  Preserve existing app architecture, authentication, localization,
    error handling, offline behavior (if already supported), and
    navigation patterns.
8.  Add or update tests and document any backend-contract uncertainties.

------------------------------------------------------------------------

## 2. Start by Inspecting the Existing Code

Before implementation:

-   Find the current Depot Registration / Depot Draft screen and every
    screen or component it uses.
-   Find the existing depot entity/domain model, API DTOs, repository,
    service, state-management layer, and API route definitions.
-   Find how the project handles:
    -   API base URLs and authenticated requests
    -   JSON serialization/deserialization
    -   success and error response envelopes
    -   loading, empty, and error states
    -   form validation and localization
    -   image/file picking and upload
    -   GPS/location permission handling
    -   dropdown/reference data caching
    -   navigation and unsaved form changes
    -   retries, request timeouts, and logging
-   Reuse current dependencies and conventions whenever practical. Do
    not add packages unless the project does not already have a suitable
    solution.
-   Do not rewrite unrelated features or introduce broad architectural
    refactors.
-   Do not guess API endpoints, response properties, enum meanings,
    required fields, or deletion endpoints. Inspect the OpenAPI
    specification and existing backend contracts where available.
-   If the backend response schema differs from the request schema,
    model the response separately from the request DTO.

At the end, provide a concise list of the existing files changed, new
files created, assumptions, and tests run.

------------------------------------------------------------------------

## 3. API Contracts

### 3.1 Create a depot draft

**Method:** `POST`\
**Path:** `/api/v1/depot-drafts`\
**Content-Type:** `application/json`

Request shape:

``` json
{
  "nameEn": "string",
  "nameKh": "string",
  "searchTerm1": "string",
  "searchTerm2": "string",
  "telephone": "string",
  "mobilePhone": "string",
  "faxNumber": "string",
  "email": "string",
  "address": {
    "provinceCode": "string",
    "districtCode": "string",
    "communeCode": "string",
    "villageCode": "string",
    "street": "string"
  },
  "location": {
    "latitude": 0,
    "longitude": 0,
    "accuracyMeters": 0
  },
  "contacts": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "nameEn": "string",
      "nameKh": "string",
      "role": "string",
      "phoneNumber": "string",
      "email": "string",
      "isPrimary": true
    }
  ],
  "remarks": "string",
  "salesAreas": [
    {
      "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "salesOrg": "string",
      "distributionChannel": "string",
      "division": "string",
      "customerGroup": "string",
      "salesOffice": "string",
      "shippingCondition": "string",
      "paymentTerms": "string",
      "salesEmployee": "string"
    }
  ],
  "creditLimit": 0,
  "creditTermDays": 0,
  "suppliers": {
    "primary": {
      "type": 1,
      "code": "string"
    },
    "secondary": {
      "type": 1,
      "code": "string"
    },
    "tertiary": {
      "type": 1,
      "code": "string"
    }
  },
  "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6"
}
```

The values above describe the shape only. Do not submit literal
`"string"` values or the example UUID. Build the payload from validated
form state.

#### Create-request implementation requirements

-   Keep JSON property names exactly as the backend expects.
-   Use nested models/DTOs for `address`, `location`, each contact, each
    sales area, and supplier entries.
-   Use numeric types for `latitude`, `longitude`, `accuracyMeters`,
    `creditLimit`, `creditTermDays`, and supplier `type` according to
    the backend schema.
-   Preserve SAP/reference codes as strings, including leading zeros
    such as `"0001"` and `"01"`. Never parse these codes into integers.
-   Generate valid UUIDs for new nested entities only if required by the
    backend contract and project conventions. Confirm whether the
    top-level `id` and nested `contacts[].id` / `salesAreas[].id` should
    be generated by the client or server. Do not invent IDs if the
    backend owns them.
-   Distinguish optional fields from required fields using the actual
    OpenAPI schema and backend validation. Do not make every field
    mandatory just because it appears in the sample.
-   For optional blank text fields, follow the backend's expected
    behavior: omit nullable fields or send `null`/empty strings only
    when the contract requires it. Do not silently change semantics.
-   Do not send invalid coordinates or placeholder zero coordinates when
    the user has not captured a location. Follow the backend's
    nullable/required contract.
-   Ensure request serialization does not accidentally include UI-only
    fields, display labels, local file paths, or transient state.
-   Parse the actual API response and preserve the returned draft ID for
    later attachment uploads and subsequent workflow steps.

### 3.2 Load reference data

**Method:** `GET`\
**Path:** `/api/v1/depots/references`

Example envelope:

``` json
{
  "success": true,
  "data": {
    "salesOrgs": [
      { "code": "0001", "name": "Phnom Penh (ISI)" },
      { "code": "0002", "name": "Building Solutions" },
      { "code": "0003", "name": "Battambang" },
      { "code": "0004", "name": "Sihanoukville" },
      { "code": "0005", "name": "Kampong Cham" },
      { "code": "0006", "name": "Kampong Thom" },
      { "code": "0007", "name": "Takeo" },
      { "code": "0008", "name": "Svay Rieng" },
      { "code": "0009", "name": "Siem Riep" },
      { "code": "0010", "name": "Kratie" },
      { "code": "0011", "name": "Pursat" },
      { "code": "0012", "name": "Banteaymeanchey" },
      { "code": "0013", "name": "Kampong Chhang" },
      { "code": "0014", "name": "Rorkar Korng" },
      { "code": "0015", "name": "Udong" },
      { "code": "0016", "name": "Svay Antor" },
      { "code": "0017", "name": "Kean Svay" },
      { "code": "0018", "name": "Tbong Khmum" },
      { "code": "0019", "name": "Phnom Penh (GVM)" },
      { "code": "0020", "name": "Export" },
      { "code": "0021", "name": "Export (GVM)" },
      { "code": "9999", "name": "Internal" }
    ],
    "distributionChannels": [
      { "code": "10", "name": "End-User" },
      { "code": "20", "name": "Local Builder" },
      { "code": "30", "name": "Craftsman" },
      { "code": "40", "name": "PIPE Maker" },
      { "code": "50", "name": "Contractor" },
      { "code": "60", "name": "Developer" },
      { "code": "70", "name": "Distributor" },
      { "code": "80", "name": "Exporter" },
      { "code": "99", "name": "Internal" }
    ],
    "customerGroups": [
      { "code": "01", "name": "End-User" },
      { "code": "02", "name": "Local Builder" },
      { "code": "03", "name": "Craftsman" },
      { "code": "04", "name": "PIPE Maker" },
      { "code": "05", "name": "Contractor" },
      { "code": "06", "name": "Developer" },
      { "code": "07", "name": "Distributor" },
      { "code": "08", "name": "Exporter" }
    ],
    "salesOffices": [
      { "code": "0001", "name": "Phnom Penh" },
      { "code": "0002", "name": "Building Solutions" },
      { "code": "0003", "name": "Battambang" },
      { "code": "0004", "name": "Sihanoukville" },
      { "code": "0005", "name": "Kampong Cham" },
      { "code": "0006", "name": "Kampong Thom" },
      { "code": "0007", "name": "Takeo" },
      { "code": "0008", "name": "Svay Rieng" },
      { "code": "0009", "name": "Siem Riep" },
      { "code": "0010", "name": "Kratie" },
      { "code": "0011", "name": "Pursat" },
      { "code": "0012", "name": "Banteaymeanchey" },
      { "code": "0013", "name": "Kampong Chhang" },
      { "code": "0014", "name": "Rorkar Korng" },
      { "code": "0015", "name": "Udong" },
      { "code": "0016", "name": "Svay Antor" },
      { "code": "0017", "name": "Kean Svay" },
      { "code": "0018", "name": "Tbong Khmum" },
      { "code": "0019", "name": "Phnom Penh (GVM)" },
      { "code": "0020", "name": "Export" }
    ],
    "shippingConditions": [
      { "code": "01", "name": "ISI Services" },
      { "code": "02", "name": "Customer Pickup" }
    ],
    "paymentTerms": [
      { "code": "BL30", "name": "LC after BL date 30days" },
      { "code": "BL45", "name": "LC after BL date 45days" },
      { "code": "BL60", "name": "LC after BL date 60days" },
      { "code": "BL90", "name": "LC after BL date 90days" },
      { "code": "LC30", "name": "LC after sight 30 days" },
      { "code": "LC45", "name": "LC after sight 45 days" },
      { "code": "LC60", "name": "LC after sight 60 days" },
      { "code": "LC90", "name": "LC after sight 90 days" },
      { "code": "LCAS", "name": "LC At sight" },
      { "code": "T007", "name": "7 days due net" },
      { "code": "T014", "name": "14 day due net" },
      { "code": "T015", "name": "15 days due net" },
      { "code": "T030", "name": "30 days due net" },
      { "code": "T045", "name": "45 days due net" },
      { "code": "T060", "name": "60 days due net" },
      { "code": "T070", "name": "70 days due net" },
      { "code": "T075", "name": "75 days due net" },
      { "code": "T090", "name": "90 days due net" },
      { "code": "T120", "name": "120 days due net" },
      { "code": "TCIA", "name": "CIA-Cash in Advance" },
      { "code": "TCOD", "name": "COD-Cash on Delivery" },
      { "code": "TN05", "name": "Due 05th next month" },
      { "code": "TN15", "name": "Due 15th next month" },
      { "code": "TN20", "name": "Due 20th next month" },
      { "code": "TN25", "name": "Due 25th next month" },
      { "code": "TN30", "name": "Due 30th next month" },
      { "code": "TN50", "name": "Due 50th next month" },
      { "code": "TN60", "name": "Due 60th next month" },
      { "code": "TN67", "name": "Due 67th next month" },
      { "code": "TN75", "name": "Due 75th next month" }
    ]
  }
}
```

The reference endpoint example above is intentionally abbreviated only
where the API contract may contain additional reference lists. Use the
actual API response as the runtime source of truth and support all
returned values. In particular, the app must not hardcode the example
arrays as its production dropdown data.

#### Reference data requirements

-   Create/update a typed response model for `success`, `data`, and the
    reference lists.
-   Create a reusable typed code/name option model for each list where
    the schemas match.
-   Preserve every `code` as a string.
-   Load reference data from the API and display each item's `name`
    while submitting its `code`.
-   Show loading, error, empty, and retry states.
-   Avoid calling the references endpoint repeatedly on every rebuild.
    Follow existing repository caching/state-management conventions and
    refresh when appropriate.
-   Do not fabricate reference lists for `division`, `salesEmployee`,
    supplier types, or geographic address codes if they are not provided
    by this endpoint. Search the existing API for their correct source.
    If no source exists, document the missing contract and avoid
    shipping hardcoded fake options.
-   `division` is present in the sales-area request, but it is not
    included in the example reference response. Confirm its valid values
    and source.
-   Do not assume `creditTermDays` is automatically derived from
    `paymentTerms`; these are distinct fields unless the
    backend/business rules explicitly define a relationship.

------------------------------------------------------------------------

## 4. Suggested Model and DTO Design

Adapt these names to the repository's naming conventions. Avoid
duplicate models if equivalent models already exist.

### Domain/form models

-   `DepotDraft`
-   `DepotAddress`
-   `DepotLocation`
-   `DepotContact`
-   `DepotSalesArea`
-   `DepotSuppliers`
-   `DepotSupplier`
-   `DepotReferenceData`
-   `DepotReferenceOption`
-   `DepotDraftAttachment`
-   `DepotDraftAttachments`

### Request DTOs

-   `CreateDepotDraftRequest`
-   `DepotAddressRequest`
-   `DepotLocationRequest`
-   `DepotContactRequest`
-   `DepotSalesAreaRequest`
-   `DepotSuppliersRequest`
-   `DepotSupplierRequest`

### Response DTOs

-   `DepotDraftResponse` (match the actual backend response)
-   `DepotReferencesResponse`
-   `DepotDraftAttachmentResponse`
-   `DepotDraftAttachmentsResponse`

### Model requirements

-   Use the project's existing serialization approach (for example,
    `json_serializable`, Freezed, or manual serialization).
-   Implement correct `fromJson` / `toJson` behavior and tests.
-   Do not force the API response to use the create-request schema if
    the response is different.
-   Keep UI labels and display values out of API DTOs unless the backend
    explicitly returns them.
-   Avoid unsafe casts. Handle nullable values and missing response
    fields consistently with project conventions.
-   Keep UUIDs, SAP codes, and other identifiers as strings.
-   Add `copyWith` or immutable state updates according to current
    project patterns.
-   Avoid mutable shared lists in state. Every add/remove/update
    operation should produce a safe state update.

------------------------------------------------------------------------

## 5. Depot Registration UI and Form Behavior

Connect the existing Depot Registration UI to the new models and real
API calls. Preserve the current app's visual design language and
navigation. Do not redesign unrelated screens.

Organize the form into clear sections or steps, using existing
components where possible.

### Section A --- Depot details

Fields:

-   English depot name --- `nameEn`
-   Khmer depot name --- `nameKh`
-   Search term 1 --- `searchTerm1`
-   Search term 2 --- `searchTerm2`
-   Telephone --- `telephone`
-   Mobile phone --- `mobilePhone`
-   Fax number --- `faxNumber`
-   Email --- `email`
-   Remarks --- `remarks`

Requirements:

-   Use appropriate keyboard types and text input actions.
-   Trim input where appropriate without changing legitimate content.
-   Validate email and phone values according to existing project rules
    and backend expectations.
-   Apply required-field rules from the backend contract, not
    assumptions.
-   Show localized, actionable validation messages.
-   Avoid losing typed values when navigating between form sections or
    when the keyboard opens/closes.

### Section B --- Address

Fields:

-   Province code --- `address.provinceCode`
-   District code --- `address.districtCode`
-   Commune code --- `address.communeCode`
-   Village code --- `address.villageCode`
-   Street --- `address.street`

Requirements:

-   Use the existing Cambodia administrative-location data/API if
    present.
-   Use cascading dropdowns when supported: selecting a province filters
    districts; selecting a district filters communes; selecting a
    commune filters villages.
-   Clear invalid downstream selections when a parent selection changes.
-   Submit codes, not display labels.
-   Do not invent geographic codes or hardcode incomplete location
    lists.
-   If the project has no geographic reference API or dataset, keep the
    UI ready for integration and document the missing dependency instead
    of submitting fabricated values.

### Section C --- GPS location

Fields:

-   Latitude --- `location.latitude`
-   Longitude --- `location.longitude`
-   Accuracy in meters --- `location.accuracyMeters`

Requirements:

-   Integrate with the project's existing location service/package.
-   Request permissions at the appropriate time and explain why location
    is needed.
-   Include a clear action such as **Capture current location**.
-   Display captured coordinates and accuracy in a readable format.
-   Handle permission denied, permanently denied, location services
    disabled, timeout, and unavailable GPS.
-   Do not block users from other form sections because GPS is
    unavailable unless the backend contract requires location.
-   Never submit `0,0` as a fake location.
-   Avoid implying that GPS coordinates are accurate if the accuracy
    value indicates otherwise.
-   Keep the captured location in form state until the user changes it.

### Section D --- Contacts

Support zero or more contacts if allowed by the backend contract. Each
contact has:

-   `id`
-   `nameEn`
-   `nameKh`
-   `role`
-   `phoneNumber`
-   `email`
-   `isPrimary`

Requirements:

-   Provide **Add contact**, **Edit contact**, and **Remove contact**
    interactions.
-   Use a stable identifier for each contact row.
-   Permit only one primary contact if this is the business rule; if not
    confirmed, check existing backend rules before enforcing it.
-   When setting a contact as primary, update the state consistently.
-   Validate contact phone/email where supplied.
-   Ensure the serialized JSON structure exactly matches the API
    contract.
-   Do not send example UUIDs. Follow the backend's ID ownership rules.

### Section E --- Sales areas

Support adding, editing, and removing sales-area rows. Each row
contains:

-   `id`
-   `salesOrg`
-   `distributionChannel`
-   `division`
-   `customerGroup`
-   `salesOffice`
-   `shippingCondition`
-   `paymentTerms`
-   `salesEmployee`

Requirements:

-   Populate supported dropdowns from `/api/v1/depots/references`.
-   Show human-readable names but submit reference codes.
-   Use searchable dropdowns if the lists are large and the current UI
    supports them.
-   Prevent accidental duplicate sales-area rows when the
    backend/business rules prohibit duplicates.
-   Support multiple sales areas when allowed by the API.
-   Do not assume that `salesOrg`, `distributionChannel`,
    `customerGroup`, `salesOffice`, `shippingCondition`, and
    `paymentTerms` all share the same reference list. Map each property
    to its corresponding list.
-   `division` and `salesEmployee` require a confirmed source. Search
    existing API endpoints and models before implementing.
-   Do not convert codes with leading zeros into integers.
-   Keep add/edit/remove actions connected to the form state.

### Section F --- Credit settings

Fields:

-   `creditLimit`
-   `creditTermDays`

Requirements:

-   Use suitable numeric input types.
-   Reject malformed values, negative values, and out-of-range values if
    prohibited by backend rules.
-   Avoid floating-point precision issues for currency where relevant;
    follow the backend's numeric type and currency rules.
-   Do not assume the currency or maximum credit limit if it is not
    specified.
-   Do not automatically overwrite `creditTermDays` based on the
    selected payment term unless the business rules explicitly require
    this.
-   Display field-level errors clearly.

### Section G --- Suppliers

The request includes:

-   `suppliers.primary.type` and `suppliers.primary.code`
-   `suppliers.secondary.type` and `suppliers.secondary.code`
-   `suppliers.tertiary.type` and `suppliers.tertiary.code`

Requirements:

-   Provide primary, secondary, and tertiary supplier selection/entry
    consistent with the existing product UX.
-   Confirm the meaning and allowed values of `type` from backend
    documentation or existing code. Do not guess what `1` means.
-   Confirm where supplier codes and supplier type options should come
    from. Use a backend reference endpoint if available.
-   If secondary or tertiary suppliers are optional, serialize them
    according to the actual contract rather than sending fabricated
    values.
-   Do not submit placeholder `"string"` values or arbitrary type
    numbers.

### Section H --- Evidence attachments

Support evidence upload using the endpoints in Section 6.

------------------------------------------------------------------------

## 6. Attachment API Integration

### 6.1 Upload an attachment

**Method:** `POST`\
**Path:** `/api/v1/depot-drafts/{id}/attachments`\
**Content-Type:** `multipart/form-data`

Form fields:

-   `file` --- required file content
-   `category` --- optional; confirm accepted values in the API schema
-   `note` --- optional
-   `takenAt` --- optional capture timestamp, if supported by the form
    schema
-   `latitude` --- optional capture latitude, if supported by the form
    schema
-   `longitude` --- optional capture longitude, if supported by the form
    schema
-   `id` --- include only if the `DepotDraftAttachmentForm` schema
    defines it; inspect the OpenAPI schema before implementing
    idempotent retries

Backend behavior described by the contract:

-   Accepted image formats: JPG, PNG, WebP.
-   Accepted document formats: PDF, DOCX.
-   Default maximum image size: 10 MB.
-   Default maximum document size: 10 MB.
-   Image content is normalized and stored as WebP, with a square
    thumbnail. Metadata is removed.
-   Image capture time and coordinates must be sent as form fields if
    needed; do not rely on embedded file metadata.
-   Documents are stored as uploaded and always download.
-   Password-protected PDFs, PDFs containing scripts, Word files with
    macros, and files containing embedded programs are refused.
-   A draft allows at most 20 evidence files and 100 MB total by
    default.
-   `201 Created` indicates a new attachment.
-   `200 OK` can indicate an idempotent resend with the same attachment
    ID and file.
-   `400 DEPOT_ATTACHMENT_INVALID_FILE` means the file is invalid.
-   `409 DEPOT_ATTACHMENT_LIMIT_REACHED` means the draft's attachment
    count or total-size limit has been reached.
-   `413` means the request is too large.
-   `429` means rate limited.

#### Upload implementation requirements

-   Inspect the `DepotDraftAttachmentForm` OpenAPI schema for exact form
    field names, data types, and required properties.
-   Use multipart upload through the existing API client and include the
    user's valid authorization token.
-   Do not manually force a JSON content type for multipart requests;
    let the multipart library set the boundary.
-   Validate file extension, MIME type, and file size client-side for
    helpful UX, while treating server validation as authoritative.
-   Do not trust a filename extension alone. Handle MIME/content
    mismatches returned by the backend.
-   Support camera/gallery and document selection only if these match
    existing product requirements and packages.
-   Show upload progress if supported by the current networking layer.
-   Prevent duplicate taps from creating concurrent duplicate uploads.
-   Handle retries safely. Use the backend's documented idempotency
    mechanism only after confirming the form schema.
-   Display per-file upload status and meaningful error messages.
-   Do not lose a selected file or form state when one attachment upload
    fails.
-   Respect the default 20-file and 100-MB limits, but allow
    configuration to follow server-provided limits if such configuration
    is available.
-   Never log access tokens, file bytes, or sensitive personal data.

### 6.2 Get attachments and refresh links

**Method:** `GET`\
**Path:** `/api/v1/depot-drafts/{id}/attachments`

The response provides the cover (nullable) and evidence files, oldest
first, with fresh links that work without an authorization token until
`urlExpiresAt`. `GetDepotDraft` may return the same attachment
information; this endpoint may be used to refresh expired links.

Requirements:

-   Model the actual `DepotDraftAttachmentsViewApiResponse` and nested
    attachment response schemas from OpenAPI.
-   Render the cover if present and list evidence files in the
    backend-provided order.
-   Use `url` and `thumbnailUrl` as returned. Do not construct, alter,
    or permanently cache expired signed URLs.
-   Track `urlExpiresAt` where returned and refresh links with the GET
    endpoint when necessary.
-   Images should support thumbnail/preview behavior; documents should
    open or download using the returned URL according to platform
    conventions.
-   Handle missing cover, empty attachments, expired links, network
    failures, unauthorized access, and not-found responses.
-   Since returned links work without a token until expiry, do not
    append the API token to those URLs.
-   Do not implement attachment deletion unless a documented backend
    endpoint exists.

### 6.3 Attachment errors

Provide clear UI messages for:

-   Invalid file type/content (`400 DEPOT_ATTACHMENT_INVALID_FILE`)
-   Attachment limit reached (`409 DEPOT_ATTACHMENT_LIMIT_REACHED`)
-   Request too large (`413`)
-   Authentication failure (`401`)
-   Permission failure (`403`)
-   Draft not found (`404`)
-   Rate limiting (`429`)
-   Network timeout/offline failure
-   Unknown server failure

Use the project's standard API error parser. Preserve backend error
codes and trace/correlation IDs for diagnostics where available, but
show user-friendly localized messages in the UI. Never show raw stack
traces or sensitive server internals to end users.

------------------------------------------------------------------------

## 7. Form Submission and Workflow

Implement the following workflow unless the existing product flow or
backend contract explicitly differs:

1.  Open Depot Registration.
2.  Load reference data and any required supporting data.
3.  Allow the user to complete the form.
4.  Validate the current form and show field-level errors.
5.  Submit the draft using `POST /api/v1/depot-drafts`.
6.  Parse the response and obtain the canonical draft ID from the actual
    response contract.
7.  If the user selected attachments, upload them using
    `/api/v1/depot-drafts/{id}/attachments` after the draft has been
    created and the returned ID is available.
8.  Refresh/retrieve attachments if needed.
9.  Show a clear success state and navigate according to existing app
    behavior.
10. If the draft creation succeeds but one or more attachment uploads
    fail, do not claim that the entire process failed or discard the
    successfully created draft. Show the draft result and which
    attachments remain failed/pending, and provide a safe retry path.

Important:

-   Do not upload attachments before the server has created the draft
    unless the API explicitly supports it.
-   Avoid creating a second draft when the user retries only a failed
    attachment upload.
-   Disable repeated submit actions while the request is in progress.
-   Use the server-returned ID instead of assuming the client-generated
    ID is the canonical ID.
-   Keep errors recoverable and preserve user-entered data where
    possible.
-   Do not invent a submit-for-approval endpoint or depot approval
    workflow. Use only documented routes and the existing application
    flow.

------------------------------------------------------------------------

## 8. State Management and Architecture

Follow the state-management approach already used by the repository (for
example, Bloc/Cubit, Riverpod, Provider, or another established
pattern).

Keep responsibilities separated:

-   **UI:** renders fields, interaction, validation, loading, and
    errors.
-   **Form/state layer:** stores current input, contacts, sales areas,
    selected references, GPS data, and attachment statuses.
-   **Repository/service:** coordinates data access and API calls.
-   **API client:** handles authentication, serialization, multipart
    requests, and transport errors.
-   **Models/DTOs:** map API data accurately.

Requirements:

-   Avoid business logic directly inside large widget build methods.
-   Do not duplicate API clients or create a second authentication
    mechanism.
-   Avoid unnecessary rebuilds and ensure dynamic list rows use stable
    keys.
-   Cancel or safely ignore stale requests when a screen is disposed,
    following project conventions.
-   Prevent race conditions when loading reference data or uploading
    files.
-   Keep the feature consistent with existing dependency injection and
    test patterns.
-   Use typed failures/results if the app already has a standard
    approach.
-   Support retry for recoverable network failures.
-   Respect offline behavior already implemented in the app. If depot
    draft submission is not currently supported offline, clearly show
    the offline state and do not claim the draft was saved to the
    server.

------------------------------------------------------------------------

## 9. Error Handling and Observability

Use the existing API error model and parser.

Handle at least:

-   `400` validation errors and backend error codes
-   `401` expired/invalid authentication
-   `403` forbidden
-   `404` draft/reference not found
-   `409` attachment limit/conflict
-   `413` file too large
-   `429` rate limiting
-   `5xx` server failures
-   timeouts, DNS/network errors, and offline mode
-   unexpected or malformed response payloads

Requirements:

-   Map backend field errors to the appropriate form fields where
    possible.
-   Preserve error codes and trace IDs in diagnostic logs if the project
    supports this.
-   Do not expose tokens, passwords, signed URLs, or sensitive personal
    data in logs.
-   Respect `Retry-After` if supplied for `429`; do not rapidly retry a
    request in a loop.
-   Do not retry non-idempotent draft creation automatically unless the
    API provides a safe idempotency mechanism.
-   Use localized, user-friendly messages and an explicit retry action
    where appropriate.

------------------------------------------------------------------------

## 10. Accessibility, Localization, and UX

-   Follow the current SteelForce design system and screen layout.
-   Keep the form practical on real mobile screens; avoid desktop-like
    dense layouts.
-   Use clear section headings and appropriate spacing.
-   Support Khmer and English using the existing localization system.
-   Do not hardcode new user-facing strings when localization is
    expected.
-   Ensure labels, error messages, dropdowns, buttons, file status, and
    loading states are accessible.
-   Preserve form values on validation failure.
-   Avoid duplicate profile/notification controls or unrelated UI
    changes.
-   Make dynamic sections (contacts, sales areas, attachments) easy to
    understand and operate.
-   Provide empty states and clear add/remove actions.
-   Ask for confirmation before removing a contact or sales area if that
    matches existing UX conventions.

------------------------------------------------------------------------

## 11. Security and Data Handling

-   Use the authenticated API client for protected endpoints.
-   Never place API secrets or service-account credentials in Flutter
    code.
-   Do not log auth tokens, sensitive contact details, or raw file
    contents.
-   Validate file types and sizes on the client for UX, but rely on
    backend validation for security.
-   Use returned signed attachment URLs only as intended and refresh
    them when expired.
-   Request location permission only when needed and explain the
    purpose.
-   Do not persist sensitive depot/contact data beyond the app's
    existing secure storage and retention conventions.
-   Keep production and development API base URLs configured through the
    project's existing environment setup.

------------------------------------------------------------------------

## 12. Testing Requirements

Add or update tests using the project's current test framework.

### Model/serialization tests

-   Parse the references response correctly.
-   Preserve codes with leading zeros (`"0001"`, `"01"`).
-   Serialize the create-draft payload with exact property names and
    nested structure.
-   Handle nullable and missing optional fields according to the API
    contract.
-   Verify that UI-only values are not included in the request.
-   Parse attachment response data, URLs, thumbnails, and expiry
    timestamps.

### Repository/API tests

-   Successful reference-data fetch.
-   Reference fetch error and retry.
-   Successful draft creation.
-   Validation error mapping.
-   Unauthorized/forbidden/not-found/server/network failures.
-   Successful multipart upload with the correct form fields.
-   Invalid attachment, file-too-large, and limit-reached errors.
-   Successful attachment listing/link refresh.
-   Rate-limit behavior and `Retry-After` handling.
-   Ensure request URLs, HTTP methods, headers, body structure, and
    multipart field names match the contract.

### UI/widget tests

-   Required-field validation.
-   Reference dropdown loading, selection, error, and retry.
-   Address cascading selection if implemented.
-   Add/edit/remove contacts.
-   Primary-contact behavior.
-   Add/edit/remove sales areas.
-   Correct display labels and submitted codes.
-   GPS success and permission-denied behavior.
-   Attachment selection, upload progress/status, failure, and retry.
-   Submit button disabled while saving.
-   Draft creation success followed by attachment upload failure.
-   Form values remain available after validation or recoverable API
    errors.
-   Khmer and English labels if localization tests exist.

### Manual QA checklist

-   Test on a real Android device or emulator and, where supported, iOS.
-   Test slow network, offline mode, expired authentication, and retry.
-   Test valid and invalid image/document files.
-   Test files close to configured size limits.
-   Test the maximum allowed attachment count/total size.
-   Verify a draft is not duplicated when only an attachment retry is
    performed.
-   Confirm the app uses real backend data rather than mock values.

------------------------------------------------------------------------

## 13. Definition of Done

The feature is complete only when:

-   [ ] Existing feature code has been inspected and reused
    appropriately.
-   [ ] Models/DTOs match the actual backend contracts.
-   [ ] `POST /api/v1/depot-drafts` is integrated.
-   [ ] `GET /api/v1/depots/references` drives supported dropdowns.
-   [ ] All visible form fields are connected to state and
    serialization.
-   [ ] SAP/reference codes remain strings and preserve leading zeros.
-   [ ] Contacts can be managed dynamically.
-   [ ] Sales-area rows can be managed dynamically.
-   [ ] GPS capture and permission/error states work.
-   [ ] Supplier type/code sources are confirmed or explicitly
    documented as blocked.
-   [ ] Attachment upload uses multipart form data and the correct
    returned draft ID.
-   [ ] Attachment list/cover/thumbnail/document links work and can be
    refreshed.
-   [ ] Upload errors and partial success are handled without losing the
    draft.
-   [ ] Loading, empty, validation, success, and error states are
    implemented.
-   [ ] Localization and existing UI conventions are preserved.
-   [ ] Tests pass and new tests cover important behavior.
-   [ ] No fake reference data, placeholder UUIDs, or literal `"string"`
    values are submitted.
-   [ ] No undocumented endpoints or business rules have been invented.
-   [ ] The final implementation report lists files changed, tests run,
    and unresolved backend questions.

------------------------------------------------------------------------

## 14. Backend Questions to Verify Before Finalizing

Do not silently guess these details. Search the OpenAPI specification,
backend implementation, or ask the backend developer if necessary.

1.  Is the top-level `id` in `POST /api/v1/depot-drafts` required,
    optional, or server-generated?
2.  Who generates IDs for contacts and sales areas?
3.  Which fields are required, nullable, or allowed to be empty?
4.  What is the exact create-draft response schema, and where is the
    canonical draft ID returned?
5.  Is there a draft update endpoint, and what is its
    method/path/request contract?
6.  What are the allowed values and source for `division`?
7.  What are the allowed values and source for `salesEmployee`?
8.  What does supplier `type` mean, and what values are valid?
9.  Where do supplier codes/options come from?
10. Is there an API or dataset for province/district/commune/village
    codes?
11. What are the accepted `category` values for attachments?
12. What is the exact `DepotDraftAttachmentForm` schema, including
    optional metadata and idempotency fields?
13. What are the exact attachment response schemas and `urlExpiresAt`
    format?
14. Are there server-provided file-size/count limits, or should the
    documented defaults be used?
15. Is a cover photo selected automatically, or is there a separate
    cover-selection API?
16. What is the intended business rule for primary contacts and
    duplicate sales areas?
17. Is `creditTermDays` independent of `paymentTerms`?
18. What is the intended next step after draft creation, and is a
    submit-for-approval endpoint documented?

If any question cannot be answered from the repository/API contract,
clearly report it as an unresolved dependency. Implement only the parts
supported by known contracts.

------------------------------------------------------------------------

## 15. Expected Work Process and Final Response

Work in this order:

1.  **Audit:** report the current implementation structure and gaps.
2.  **Plan:** identify the smallest set of changes needed.
3.  **Implement:** update models, repository/API integration, state
    management, and UI in coherent steps.
4.  **Verify:** run formatter, analyzer/linter, and relevant tests using
    the commands appropriate for this repository.
5.  **Review:** inspect the diff for incorrect field names, fake
    reference values, duplicated logic, and unhandled error states.
6.  **Report:** provide a concise summary including:
    -   What was changed
    -   Files created/updated
    -   Endpoints integrated
    -   Validation and error behavior
    -   Tests and commands run, with actual results
    -   Any remaining backend questions or blocked functionality

Do not claim tests passed unless you actually ran them. Do not stop
after producing a plan: implement the feature in the existing repository
wherever the environment allows.

## Final instruction

**Update the current SteelForce Depot Registration feature in place to
match the backend contract and requirements in this document.** Keep the
implementation consistent with the existing Flutter codebase, connect
every relevant UI control to real data and API behavior, and document
anything that cannot be completed because the backend contract is
missing or ambiguous.
