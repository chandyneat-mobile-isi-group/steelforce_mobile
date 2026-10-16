# Demo mode — running the app with no backend

> **Purpose:** how to build and present the app with static demo data, and what
> it does and does not simulate.
> **Verified:** 2026-10-14, branch `app-static`.

Demo mode is a **compile-time** switch. A build made without it is the normal
app, byte-for-byte in behaviour: every demo class sits behind the constant
`DataSourceMode.useMocks` (`lib/core/config/data_source_mode.dart`) and is
tree-shaken out of a live build.

---

## Run it

```bash
# Browser
flutter run -d chrome --dart-define=USE_MOCK_DATA=true

# Android / iOS device or emulator
flutter run --dart-define=USE_MOCK_DATA=true

# A hostable web build (static files in build/web)
flutter build web --release --dart-define=USE_MOCK_DATA=true
```

Sign in with **`123456789` / `123456789`** — or tap **Fill demo account** on the
sign-in screen. The password-reset code is **`123456`**.

No `.env` change is needed. `API_BASE_URL` is still compiled in, but nothing in
a demo build sends to it.

## The DEMO strip — switching online and offline

A thin **DEMO · online** strip sits at the top of every screen. **Tap it** to
take the simulated network offline (the dot turns red) and tap again to bring
it back. Offline behaves as a real dropped signal: the offline notice shows,
writes queue locally, and the queue drains when you switch back online.

## What is simulated

| Area | Demo behaviour |
|---|---|
| Sign-in, profile, password change/reset | Local demo account; tokens are opaque placeholders |
| Depots (12), registration drafts, documents | In-memory demo backend, shared ids across features |
| Routes and visits | Today's route of 6 stops, past and future days; check-in/out, ad-hoc visits |
| Check-in location | The rep is placed on the stop's pin, so the geofence passes anywhere |
| Stock step after check-in | Visit step 4: one **Take or upload photos** control (take a photo, or upload several at once, up to 10). **Submit** needs at least 3, saves them to the visit like any stock photo, and opens the usual "Inventory photo submitted" screen (Create quotation / Complete visit). No report is generated. Live builds keep the single stock photo. A visit step bar (Stop → Details → Check in → Inventory → Check out) shows on Stop information, Check-in and this step |
| Complete visit | One tap, no "how did the visit end" sheet: checks out with the quotations taken at the stop, or as "other" with the note *Completed from the demo app (no reason asked)*, then lands on Home. Create quotation is hidden on the inventory success screen. Live builds keep the sheet and the button |
| Catalog, pricing, stock, material finder | Bundled ISI demo catalogue |
| Quotations & orders | **Switched off** (`FeatureFlags.quotesAndOrders`): the Orders tab and the home "My quotes & orders" tile show *coming soon*; Create quotation buttons (stop card, depot card, inventory success), the Stop information Sales tab, and resuming into a quotation are hidden. The demo quotation data still exists behind the switch |
| Notifications | Seeded inbox referencing the demo depots and quotes |
| Push (FCM) | Off — the no-op transport is used, Firebase never starts |

Every demo write lives in memory: **reloading the page or restarting the app
resets the demo backend** (data already synced to the device's local database
survives until sign-out).

## What it does not do

- **Sales orders start empty.** They are created on the device from a
  quotation, as in the live app; there is no server feed to seed.
- **Submitted quotations stay "Pending approval"** — nothing approves them.
- **Proof photos on web** open the browser's file picker; there is no camera.
- **Third-party assets still load from the internet:** Google Maps tiles and
  SDK, the Flutter web engine (CanvasKit) and fonts from `gstatic.com`. None of
  these is the ISI backend. For a fully offline web demo, those must be
  self-hosted; that is not set up.

## How it is wired (for developers)

- One switch: `DataSourceMode.useMocks`. Each feature's `*_injection.dart`
  picks `Api…RemoteDataSource` or `Demo…RemoteDataSource` from it.
- Demo sources live in each feature's `data/mock/`; shared identities (depot
  ids, demo account) in `lib/core/demo/demo_seed.dart`; the online/offline
  switch is `lib/core/demo/demo_network.dart`.
- **Safety net:** in a demo build every `dio` client gets
  `DemoNetworkGuardAdapter`, which refuses every request. A data source added
  later without a demo counterpart fails as "offline" and prints
  `[isi.demo] BLOCKED network request…` in debug builds — it never reaches a
  real host.
- Adding a remote data source? Add its demo twin in the same change, or it will
  show as offline in demo builds.
