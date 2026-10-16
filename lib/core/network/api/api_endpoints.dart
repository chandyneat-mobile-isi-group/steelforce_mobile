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
  /// (`docs/Authentication-guild-integratemobile.md`, "Base URL"). Only the
  /// host varies per environment, and that half comes from
  /// `AppConfig.apiBaseUrl`.
  static const String apiPrefix = '/api/v1';

  // ── Auth endpoints ─────────────────────────────────────────────────
  // Tokens come only from `login` and `refresh` — there is no separate token
  // endpoint. Both are OAuth 2.0 endpoints: they answer with
  // `{error, error_description}` at HTTP 400, *not* with a problem document
  // and not with 401. Everything else answers RFC 9457. See `ApiError`.
  static const String loginEndpoint = '$apiPrefix/mobile/auth/login';

  // ── Forgot password by SMS code (three steps) ──────────────────────
  //
  // No token exists yet — the rep cannot sign in — so these are **not**
  // under `/mobile/`, which requires one (staging answers 401 there).
  // Steps 1 and 2 send `recoveryMethod: "phone"`; the server also accepts
  // "email", which this app does not use.

  /// `POST {recoveryMethod, phoneNumber}` — texts a code to the rep's phone.
  /// Answers 200 whether or not the number is registered.
  static const String sendOtpEndpoint =
      '$apiPrefix/auth/forgot-password/request';

  /// `POST {recoveryMethod, phoneNumber, otp}` — checks the 6-digit code and
  /// answers with a one-time `resetToken` and the `passwordPolicy`.
  static const String verifyOtpEndpoint =
      '$apiPrefix/auth/forgot-password/verify-otp';

  /// `POST {resetToken, newPassword, confirmPassword}` — sets the new
  /// password. Signs the account out everywhere.
  static const String resetOtpEndpoint =
      '$apiPrefix/auth/forgot-password/reset';

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
  /// lastLoginAt, lineManager}`. Read-only.
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

  /// Routes that must never trigger the interceptor's refresh-and-replay: a
  /// 401 from one of these is the answer, not a stale-token symptom.
  static const Set<String> authRoutes = {
    loginEndpoint,
    refreshEndpoint,
    // Forgot password runs signed out — there is no token to refresh.
    sendOtpEndpoint,
    verifyOtpEndpoint,
    resetOtpEndpoint,
  };

  // ── Mobile depot endpoints ──────────────────────────────────────
  static const String depotsEndpoint = '$apiPrefix/mobile/depots';

  /// Depot discount agreements / incentives per
  /// `docs/feature/prom-discount/promotions-discounts-plan.md` §8.1.
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
  // Per `docs/feature/quotation-orders/api/mobile.md`.
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
  /// `docs/feature/depot/mobile/mobile.md` §Looking a depot up by code.
  static const String depotsByCodeEndpoint = '$apiPrefix/depots/by-code';

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

  // ── Mobile notification endpoints ──────────────────────────────────
  //
  // Per `docs/feature/notification/README.md` §3. The same routes also exist
  // without the `/mobile` segment for the admin portal — same handlers,
  // different envelope. **Use these**, or the response comes back in the
  // portal's shape and every parse fails.
  //
  // All of these require authentication. The inbox and preference routes
  // additionally need `notifications.read`, which every seeded role holds.
  // Device registration deliberately requires **only** authentication: a rep
  // who cannot read notifications must still be able to tell the platform
  // their token changed.

  /// `POST` — register or refresh this installation's FCM token. Idempotent on
  /// `deviceId`, so calling it on every launch costs one cheap round trip;
  /// calling it less often is how a rep silently stops receiving anything
  /// (§4.1).
  static const String deviceRegisterEndpoint =
      '$apiPrefix/mobile/devices/register';

  /// `GET` — the rep's registered installations.
  static const String devicesEndpoint = '$apiPrefix/mobile/devices';

  /// `DELETE` — deregister on sign-out. **Call before discarding the access
  /// token**, or the platform keeps pushing one rep's notifications at a
  /// handset that has since been handed to somebody else (§4.4).
  static String deviceEndpoint(String deviceId) => '$devicesEndpoint/$deviceId';

  /// `GET` — the inbox, paged and filtered. The guaranteed delivery path: this
  /// is what makes a dropped push cost nothing (§1).
  static const String notificationsEndpoint = '$apiPrefix/mobile/notifications';

  /// `GET` — badge figures. Cheap enough to call on every foreground, and the
  /// only correct source for them: a locally incremented counter drifts the
  /// first time a push is dropped (§7).
  static const String notificationCountsEndpoint =
      '$notificationsEndpoint/unread-count';

  /// `PATCH` — mark one read. Idempotent; the first read timestamp wins.
  static String notificationReadEndpoint(String id) =>
      '$notificationsEndpoint/$id/read';

  /// `PATCH` — mark all read, optionally scoped by `?category=`.
  static const String notificationReadAllEndpoint =
      '$notificationsEndpoint/read-all';

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
