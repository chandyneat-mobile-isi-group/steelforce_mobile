/// Every backend route the app calls, rooted at [apiPrefix].
///
/// Only paths live here. The host is environment-specific and comes from
/// `AppConfig.apiBaseUrl` (see `AppNetwork`); timeouts and paging limits are
/// [ApiDefaults]. Split out of the former catch-all `AppConstants`.
library;

abstract final class ApiEndpoints {
  // ── API ────────────────────────────────────────────────────────────
  // NOTE: there is deliberately no `baseUrl` constant here. The gateway host is
  // environment-specific and comes from `AppConfig.apiBaseUrl` (see
  // `AppNetwork`). A hardcoded literal previously lived here and pinned every
  // build — including QA and staging — to the production host.
  /// Every documented route is rooted at `https://<host>/api/v1`
  /// (`docs/feature/authentication/backend-auth-guide.md`, "Base URL"). Only the
  /// host varies per environment, and that half comes from
  /// `AppConfig.apiBaseUrl`.
  static const String apiPrefix = '/api/v1';

  // ── Auth endpoints ─────────────────────────────────────────────────
  // Tokens come only from `login` and `refresh` — there is no separate token
  // endpoint. Both are OAuth 2.0 endpoints: they answer with
  // `{error, error_description}` at HTTP 400, *not* with a problem document
  // and not with 401. Everything else answers RFC 9457. See `ApiError`.
  static const String loginEndpoint = '$apiPrefix/mobile/auth/login';

  // ── Firebase phone password reset ─────────────────────────────────

  /// `POST {resetToken, newPassword, confirmPassword}` → 200. Sets the new
  /// password and signs the account out everywhere. A password that fails
  /// the policy leaves the token usable.
  /// docs/feature/authentication/mobile-integration.md, A5.
  static const String resetOtpEndpoint =
      '$apiPrefix/auth/forgot-password/reset';

  /// `POST {phoneNumber}` → `{expiresAt, expiresIn, codeLength}`: the first
  /// step of both phone password flows (forgot and change), before Firebase
  /// sends the SMS. The body is that one field only; the answer carries no
  /// phone number, so Firebase gets the number that was sent. Rate-limited per
  /// number (429 with `Retry-After`).
  static const String startFirebaseResetEndpoint =
      '$apiPrefix/auth/otp/request';

  /// `POST {firebaseIdToken}` → `{resetToken, expiresIn, passwordPolicy}`:
  /// exchanges Firebase's proof for a one-time reset token, signed out. Only
  /// for the number of an open verification from
  /// [startFirebaseResetEndpoint]. Step 2 is [resetOtpEndpoint].
  ///
  /// Not `auth/password/phone/verify`: that one is for a signed-in rep's own
  /// number and needs a bearer token.
  static const String verifyFirebaseResetEndpoint =
      '$apiPrefix/auth/forgot-password/phone/verify';

  /// `POST {refreshToken}` → `{data: {accessToken, refreshToken, …}}`.
  /// Rotates the refresh token: store the new one and discard the old —
  /// sending a used one ends the whole session. Not `/auth/refresh`: that is
  /// the web portal's cookie route and never returns a refresh token.
  static const String refreshEndpoint = '$apiPrefix/mobile/auth/refresh-token';

  static const String logoutEndpoint = '$apiPrefix/auth/logout';

  /// The signed-in user's profile: `{id, email, englishName, khmerName,
  /// empCode, phone, passwordChangeRequired, temporaryPasswordExpiresAt,
  /// lastLoginAt, lineManager, isAdmin}`. Not under `/mobile/` — there is no
  /// `/mobile/auth/me` (404).
  static const String currentUserEndpoint = '$apiPrefix/auth/me';

  /// The rep's own profile for the profile screen, `GET`: `{id, employeeCode,
  /// fullName, khmerName, phoneNumber, email, role, passwordChangeRequired,
  /// lastLoginAt, lineManager, saleOrg}`. Read-only.
  static const String myProfileEndpoint = '$apiPrefix/mobile/auth/profile';

  /// The rep's own profile photo — the **only** part of their profile they
  /// may change.
  ///
  /// * `POST multipart/form-data`, the image in the field `file` (JPG, PNG or
  ///   WebP, ≤ 5 MB) — upload or replace. The server turns it upright,
  ///   shrinks it, strips metadata and stores a WebP plus a square thumbnail.
  /// * `DELETE` — remove it (`204`, also when there was none).
  /// * `GET` — fresh signed `url` / `thumbnailUrl`.
  ///
  /// Not under `/mobile/`. The signed URLs reach the app through
  /// [myProfileEndpoint] (`profilePhotoUrl`, `profilePhotoThumbnailUrl`).
  static const String profilePhotoEndpoint = '$apiPrefix/users/profile-photo';

  /// Only `POST {sessionsEndpoint}/current/location` is used — the location
  /// heartbeat (`core/session/location_heartbeat_service.dart`). **Not on
  /// staging yet**, so each heartbeat fails until the backend adds it.
  static const String sessionsEndpoint = '$apiPrefix/mobile/auth/sessions';

  static const String changePasswordEndpoint =
      '$apiPrefix/mobile/auth/change-password';

  // ── Signed-in password change, proven by an SMS to the own number ──
  //
  // docs/feature/authentication/mobile-integration.md, Flow B. All three need
  // the bearer token; the number always comes from the account.

  /// The signed-in change-password flow starts the same way as forgot
  /// password: `{phoneNumber}` with the account's own number.
  static const String startOwnPhoneVerificationEndpoint =
      startFirebaseResetEndpoint;

  /// `{firebaseIdToken}` → `{phoneProofToken, expiresIn}`. Single use.
  static const String verifyOwnPhoneEndpoint =
      '$apiPrefix/auth/password/phone/verify';

  /// `{phoneProofToken, newPassword}` → 204. The same `ChangePasswordRequest`
  /// as [changePasswordEndpoint], which also accepts the proof.
  static const String changePasswordWithProofEndpoint =
      '$apiPrefix/auth/password';

  /// Routes that must never trigger the interceptor's refresh-and-replay: a
  /// 401 from one of these is the answer, not a stale-token symptom.
  static const Set<String> authRoutes = {
    loginEndpoint,
    refreshEndpoint,
    // Forgot password runs signed out — there is no token to refresh.
    resetOtpEndpoint,
    startFirebaseResetEndpoint,
    verifyFirebaseResetEndpoint,
  };

  // ── Mobile depot endpoints ──────────────────────────────────────
  static const String depotsEndpoint = '$apiPrefix/mobile/depots';

  /// Depot discount agreements / incentives per
  /// `docs/feature/order/promotions/plan.md` §8.1.
  static String depotAgreementsEndpoint(String depotId) =>
      '$depotsEndpoint/$depotId/agreements';

  static String depotIncentivesEndpoint(String depotId) =>
      '$depotsEndpoint/$depotId/incentives';

  static String depotPromotionsEndpoint(String depotId) =>
      '$depotsEndpoint/$depotId/promotions';

  /// The outlet profile and credit position shown on a visit's stop screen.
  ///
  /// Fetched when a stop is opened, **not** with the route sync: the route feed
  /// carries only what a stop card and a map pin need, and this is the rest.
  ///
  /// `{depotId}` is the same GUID the route sync already puts on every stop.
  /// See `docs/feature/depot/mobile/backend-change-notice.md` §2.
  static String depotStopInformationEndpoint(String depotId) =>
      '$depotsEndpoint/$depotId/stop-information';

  static const String discountAuthorityEndpoint =
      '$apiPrefix/mobile/me/discount-authority';

  // ── Mobile quotation endpoints ─────────────────────────────────────
  // Per `docs/feature/order/quotation/api/mobile.md`.
  static const String quotationsEndpoint = '$apiPrefix/mobile/quotations';

  static String quotationEndpoint(String id) => '$quotationsEndpoint/$id';

  static String quotationLinesEndpoint(String id) =>
      '$quotationsEndpoint/$id/lines';

  static String quotationLineEndpoint(String id, String lineId) =>
      '$quotationsEndpoint/$id/lines/$lineId';

  static String quotationDiscountsEndpoint(String id) =>
      '$quotationsEndpoint/$id/discounts';

  static String quotationPreviewEndpoint(String id) =>
      '$quotationsEndpoint/$id/preview';

  static String quotationRepriceEndpoint(String id) =>
      '$quotationsEndpoint/$id/reprice';

  static String quotationSubmitEndpoint(String id) =>
      '$quotationsEndpoint/$id/submit';

  static String quotationCancelEndpoint(String id) =>
      '$quotationsEndpoint/$id/cancel';

  static String quotationHistoryEndpoint(String id) =>
      '$quotationsEndpoint/$id/history';

  /// `GET /depots/by-code/{code}` — the **portal** surface, deliberately not
  /// under `/mobile`.
  ///
  /// It answers with the portal envelope (`data` + `meta`, no `success`) and the
  /// portal depot shape (`code` not `depotCode`, a nested `address`, a
  /// bare `creditLimit` number), so it needs its own parser. Documented as a
  /// rough edge rather than a design — see
  /// `docs/feature/depot/mobile/api.md` §Looking a depot up by code.
  static const String depotsByCodeEndpoint = '$apiPrefix/depots/by-code';

  // ── Depot drafts (new depot registration) ──────────────────────────
  // Per the backend's `features/create-depot/api-contract.md` and
  // `attachments.md`. Not under `/mobile`: the portal and the app share them.

  /// The route a depot draft lives on. The app creates one through
  /// `POST /mobile/depots` ([depotsEndpoint]) with `depotType` `DEPOT`.
  static const String depotDraftsEndpoint = '$apiPrefix/depot-drafts';

  /// `POST` multipart (`file`, `id`, `category`, `note`, `takenAt`,
  /// `latitude`, `longitude`) adds evidence; `GET` returns the cover and the
  /// evidence with fresh signed links.
  static String depotDraftAttachmentsEndpoint(String draftId) =>
      '$depotDraftsEndpoint/${Uri.encodeComponent(draftId)}/attachments';

  /// A non-depot's own route. `POST /mobile/depots` with `depotType`
  /// `NON_DEPOT` creates one here; its files hang off it like a draft's.
  static const String nonDepotsEndpoint = '$apiPrefix/non-depots';

  static String nonDepotAttachmentsEndpoint(String id) =>
      '$nonDepotsEndpoint/${Uri.encodeComponent(id)}/attachments';

  /// `GET` — the six SAP pick lists a sales area is filled from, each
  /// `[{code, name}]`, `[]` when never synced.
  static const String depotReferencesEndpoint = '$apiPrefix/depots/references';

  /// `GET /profile-lists/{list}` — `branch` and `factory` are the supplier
  /// options a draft ranks. Active values only unless `includeInactive=true`.
  static String profileListEndpoint(String list) =>
      '$apiPrefix/profile-lists/${Uri.encodeComponent(list)}';

  // ── Mobile materials endpoints ─────────────────────────────────────
  //
  // The guided selection surface, per
  // `docs/feature/order/product-selection/api.md`.
  // All of them require `materials.read` and answer the standard envelope; a
  // 403 with no `errorCode` means the role is missing that permission, not
  // that the request is malformed.
  //
  // None of these calls SAP — they read the platform's own synced copy of the
  // material master, which is why the finder keeps working when the ERP does
  // not. The one exception is [materialAvailabilityEndpoint], which is a live
  // SAP round trip and must only be called when a rep commits to a material.
  static const String materialsEndpoint = '$apiPrefix/mobile/materials';

  /// Stage zero — the categories that open the finder.
  static const String materialCategoriesEndpoint =
      '$materialsEndpoint/selection/categories';

  /// The wizard's shape for one category (or every published one).
  /// Configuration, not catalogue data: fetch once per session and cache it.
  static const String materialSchemaEndpoint =
      '$materialsEndpoint/selection/schema';

  /// The options for exactly one step. `{attribute, selection}`.
  static const String materialFacetsEndpoint =
      '$materialsEndpoint/selection/facets';

  /// The terminal read. `{selection, page, pageSize, search}` — note the
  /// different body shape from the facet call; putting the selection fields at
  /// the top level here is silently read as an empty selection.
  static const String materialSelectionEndpoint =
      '$materialsEndpoint/selection/materials';

  /// Banded on-hand stock for one material, with a per-plant breakdown.
  ///
  /// `{ material, band, isSellable, baseUnit, plants[], checkedAt }` — a band
  /// (`High` / `Medium` / `Low` / `None`), never a quantity. This is the read
  /// the order flow uses to decide whether a rep may set a quantity at all.
  static String materialStockEndpoint(String material) =>
      '$materialsEndpoint/$material/stock';

  /// SAP's live sellability verdict for one material.
  ///
  /// Note the path: this one sits at `/materials/...`, **not** under the
  /// `/mobile/` prefix the rest of this block uses. Verified against the
  /// staging host; deriving it from [materialsEndpoint] would 404.
  ///
  /// Unlike every other call here it is a live SAP round trip, so it is slow
  /// and it fails when the middleware is down. Call it when a rep commits to a
  /// material — never while they browse.
  static String materialAvailabilityEndpoint(String material) =>
      '$apiPrefix/materials/$material/availability';

  /// Depot-specific prices for one or more materials.
  ///
  /// `GET /mobile/pricing/depots/{depotId}?materials=A&materials=B` —
  /// the `materials` parameter repeats rather than taking a delimited list, so
  /// a quotation with eight lines is one round trip instead of eight.
  static String depotPricingEndpoint(String depotId) =>
      '$apiPrefix/mobile/pricing/depots/$depotId';

  /// The realtime pricing hub. The access token rides on the query string,
  /// which is the transport's own contract — browsers and sockets cannot set
  /// an Authorization header on the handshake.
  static const String pricingHubPath = '/hubs/pricing';

  // ── Mobile visit endpoints (docs/feature/my-visits/api.md) ──────────────
  //
  // Scope is always the signed-in rep: the server derives `repId` from the
  // bearer token. The client sends `territory` to narrow the result set, never
  // as an authorisation claim — a client-supplied rep identity is not trusted
  // and is not sent.
  /// `GET` — the rep's routes, paginated, with a flat de-duplicated
  /// `depots` list each stop joins to by `depotId`.
  static const String visitRoutesEndpoint = '$apiPrefix/mobile/visits/routes';

  /// `GET` — the caller's visit plans for `period` (`Today`, `ThisWeek`,
  /// `ThisMonth` — the default), with the period's counts and every plan by
  /// date, then depot code. Only the caller's own plans: the sale code comes
  /// from the access token, so no territory or employee code is sent.
  static const String mobilePlansEndpoint = '$apiPrefix/mobile/plans';

  /// `GET` — same body as [mobilePlansEndpoint] with `period=Today`. Feeds the
  /// Visits list; [mobilePlansEndpoint] feeds the calendar.
  static const String mobilePlansTodayEndpoint = '$mobilePlansEndpoint/today';

  /// `POST` `{ visitId, outletType, depotCode | nonDepotId }` — an unplanned
  /// visit for today as a Draft plan: 201 new, 200 when the same `visitId` is
  /// sent again.
  static const String mobilePlansAdHocEndpoint = '$mobilePlansEndpoint/ad-hoc';

  /// `POST` `{ "reason": "…" }` (1–500 chars) — Planned or CheckedIn →
  /// Skipped, only on the plan's own date. [planId] is the plan id, never a
  /// depot code.
  static String mobilePlanSkipEndpoint(String planId) =>
      '$mobilePlansEndpoint/${Uri.encodeComponent(planId)}/skip';

  /// `GET` — one plan with `depotLocation`, `radiusMeters` and `checkIn`.
  static String mobilePlanEndpoint(String planId) =>
      '$mobilePlansEndpoint/${Uri.encodeComponent(planId)}';

  /// `POST` multipart — check in with GPS and 1–5 photos; a reason is
  /// required outside the zone. Idempotent on the client's `checkInId`.
  static String mobilePlanCheckInEndpoint(String planId) =>
      '${mobilePlanEndpoint(planId)}/check-in';

  /// `POST` multipart — 1–10 stock photos in `photos` plus the client's
  /// `uploadId`, while the visit is CheckedIn. Each upload adds to the visit.
  static String mobilePlanInventoryPhotoUploadEndpoint(String planId) =>
      '${mobilePlanEndpoint(planId)}/inventory-check-photo-upload';

  /// `POST` JSON — CheckedIn → Completed with GPS, optional notes and the
  /// client's `checkOutId`. Needs at least one inventory photo first.
  static String mobilePlanCheckOutEndpoint(String planId) =>
      '${mobilePlanEndpoint(planId)}/check-out';

  /// `GET` — same body shape as [visitRoutesEndpoint], narrowed by `since`.
  /// Deliberately a full re-pull of the rep's current scoped set rather than a
  /// row-level diff: a rep has a handful of routes a day, so the simplicity is
  /// worth more than the bytes.
  static const String visitRoutesDeltaEndpoint = '$visitRoutesEndpoint/delta';

  /// `POST` — one batch carrying every pending capture of every kind.
  /// Answers 200 with an accepted/rejected id split; a single bad row must
  /// never fail the batch.
  static const String visitPushEndpoint = '$apiPrefix/mobile/visits/push';

  /// `POST` — add a depot the Call Plan missed to *today*.
  ///
  /// Takes `{depotId, clientRequestId}` and nothing else. **Never send
  /// `visitDate`**: the server derives today, and supplying one is rejected as
  /// `Visit.AdHocDateInvalid` (`ad-hoc-visits-mobile.md` §4). There is no
  /// `repId` field and there never will be — the rep comes from the token.
  static const String visitAdHocEndpoint = '$apiPrefix/mobile/visits/ad-hoc';

  // ── Live check-in / check-out (check-in-check-out-mobile.md §2) ──────
  // Online twins of the `checkIns` / `checkOuts` push rows. Same body, same
  // client ids, idempotent on them — the server stores a row identically
  // whichever way it arrives.

  /// `POST` — check in at a stop. Answers the server's `VisitDto`.
  static const String visitCheckInsEndpoint =
      '$apiPrefix/mobile/visits/check-ins';

  /// `POST` — check out, with or without order. Answers the `VisitDto`.
  static const String visitCheckOutsEndpoint =
      '$apiPrefix/mobile/visits/check-outs';

  /// `GET` — the "no order" reasons, cached for offline check-out.
  static const String visitCheckOutReasonsEndpoint =
      '$apiPrefix/mobile/visits/check-out-reasons';

  // ── Notification endpoints ─────────────────────────────────────────
  //
  // The signed-in user's own devices and inbox, under `/me` (backend
  // `DeviceEndpoints` / `InboxEndpoints`). All require authentication.

  /// `PUT` — register or refresh this installation's FCM token.
  static String deviceRegisterEndpoint(String installationId) =>
      '$apiPrefix/me/devices/$installationId';

  /// Base path for this user's installation registration.
  static const String devicesEndpoint = '$apiPrefix/me/devices';

  /// `DELETE` — unregister on sign-out, before discarding the access token.
  static String deviceEndpoint(String deviceId) => '$devicesEndpoint/$deviceId';

  /// `GET` — the signed-in user's inbox, newest first, keyset-paged by
  /// `cursor` (`data.nextCursor`), `limit` 1–50 and `unreadOnly`. The
  /// guaranteed delivery path: this is what makes a dropped push cost nothing.
  static const String notificationsEndpoint = '$apiPrefix/me/notifications';

  /// `GET` — `data.count`, the unread figure for the bell.
  static const String notificationCountsEndpoint =
      '$notificationsEndpoint/unread-count';

  /// `POST` → 204 — mark one read. Idempotent; the first read time is kept.
  /// Another user's id answers 404 `NOTIFICATION_NOT_FOUND`.
  static String notificationReadEndpoint(String id) =>
      '$notificationsEndpoint/$id/read';

  /// `POST` — mark all read; `data.marked` is how many were unread.
  static const String notificationReadAllEndpoint =
      '$notificationsEndpoint/read-all';

  // The action, dismiss and preferences routes below are not served by the
  // backend yet (`InboxEndpoints` maps only list, unread-count, read and
  // read-all). Nothing in the inbox UI calls them.

  /// `POST` — record that the rep **acted**. The only call that closes an item
  /// requiring acknowledgement; wiring "scrolled past it" here instead of to
  /// `/read` silently breaks the supervisor escalation chain (§8.3).
  static String notificationActionEndpoint(String id) =>
      '$notificationsEndpoint/$id/action';

  /// `DELETE` — dismiss. A state change, not a deletion; answers 409 when the
  /// item requires acknowledgement.
  static String notificationDismissEndpoint(String id) =>
      '$notificationsEndpoint/$id';

  /// `GET`/`PUT` — the settings screen. Build it from the response's
  /// `categories`, never from a list compiled into the app (§13).
  static const String notificationPreferencesEndpoint =
      '$notificationsEndpoint/preferences';
}
