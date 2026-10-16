# Feature & UI Standard

> **The gate every new feature, screen, widget, or visual upgrade must pass before merge.**
>
> This is not a style opinion piece. Each rule is checkable, cites a real API in
> this codebase, and exists because something concrete went wrong (or would).
> Rules are numbered so a review comment can say "FS-RSP-3" instead of an essay.
>
> **Scope:** anything a user can see or touch, plus the code behind it.
> **Companion docs** — this file does not duplicate them, it gates on them:
> `docs/skills/engineering-standard.md` (cross-cutting rules), `docs/blueprint/system-architecture.md` (layering),
> `docs/skills/security.md` (threat model), `docs/blueprint/offline-architecture.md`, `docs/blueprint/sync-architecture.md`,
> `docs/skills/ai-engineering-playbook.md` (worked example).

---

## 0. How to use this

Three checkpoints. Skipping one is how regressions ship.

| When | Do this |
|---|---|
| **Before writing code** | Read §1. Run `graphify affected "<symbol>" --depth 1` for blast radius. Confirm the infrastructure you depend on exists (`docs/blueprint/migration-plan.md`) — do not build ahead of it. |
| **While building** | Follow §2–§13 for the categories you touch. |
| **Before opening a PR** | Copy §14 into the PR description and tick every line honestly. An unticked box is fine; a falsely ticked one is not. |

**The one-line test:** *Would this still be correct on a 390pt phone, a 1032pt
iPad, in Khmer, offline, on a slow device, at 200% font scale, in dark mode,
two years from now?* If you cannot answer yes to all eight, it is not done.

---

## 1. Non-negotiables (a PR violating these is blocked, not debated)

- **FS-NN-1** — `flutter analyze` introduces **zero** new issues. Baseline is
  tracked; you may not add to it.
- **FS-NN-2** — `flutter test` passes. New Bloc/Cubit ⇒ new `blocTest`. New
  screen ⇒ at least one widget test.
- **FS-NN-3** — No secrets, tokens, keys, endpoints, PII, or revenue figures in
  source, logs, or analytics. See §2.
- **FS-NN-4** — No user-visible crash path. Every async failure has a handled,
  translated state. See §3.
- **FS-NN-5** — No hardcoded demo/mock data in a production widget. If
  temporarily unavoidable it **must** carry `// TODO(release-gate):` and be
  listed in the PR description.
  > Live example of the failure: `main_shell.dart` renders a hardcoded
  > `'Sokha Novel'` and `targetAmount: 1000000` to every authenticated user.
- **FS-NN-6** — Domain layer imports no Flutter, Drift, or `dio` types
  (`docs/blueprint/system-architecture.md` §2, ADR-003). Responsive/UI logic never leaves
  presentation.
- **FS-NN-7** — Any write to a syncable table enqueues its sync row in the
  **same Drift transaction** (ADR-006). Correctness rule, not style.

---

## 2. Security

Full model in `docs/skills/security.md`. Gate:

- **FS-SEC-1** — Secrets live only in `flutter_secure_storage`; business data
  only in the encrypted Drift database. Never `SharedPreferences`, never Hive,
  never a plaintext file.
- **FS-SEC-2** — Log only: endpoint, status code, error code, stack trace
  (debug builds). **Never** names, phones, emails, addresses, GPS traces,
  prices, or revenue. Use `core/logging/app_logger.dart`; it redacts.
- **FS-SEC-3** — No `print()`. `debugPrint` must be unreachable in release.
- **FS-SEC-4** — No hand-rolled cryptography. Use the composite key scheme in
  `docs/blueprint/local-storage-architecture.md` §2 and platform primitives only.
- **FS-SEC-5** — New permission (camera, location, mic, storage) requires: a
  written justification in the PR, a runtime rationale UI, and graceful denial
  handling. `ACCESS_BACKGROUND_LOCATION` additionally needs Play Console
  justification text.
- **FS-SEC-6** — Protected actions go through `AuthGuard.requireAuthentication`.
  Guests must degrade to a prompt, never a crash or a blank screen.
- **FS-SEC-7** — Screens showing depot or pricing data must not leak into
  screenshots/recents where the platform offers protection.

---

## 3. Stability — the app must not crash

- **FS-STB-1** — Every `Future` in the UI has an error path that renders a
  **translated** error state. No unhandled rejections.
- **FS-STB-2** — After every `await`, guard `BuildContext` use with
  `if (!context.mounted) return;`. This is the single most common Flutter crash
  in this repo's lint baseline.
- **FS-STB-3** — Dispose everything you create: `AnimationController`,
  `TextEditingController`, `ScrollController`, `StreamSubscription`,
  `ValueNotifier` listeners. Pair every `addListener` with `removeListener`.
- **FS-STB-4** — Never `!` on a nullable you did not just null-check. Never
  index a list without a bounds check. Never `late` a field that a failed async
  call could leave unset.
- **FS-STB-5** — Offline is a **normal state, not an error state** (ADR-002 §4).
  No feature may hard-fail because the network is absent.
- **FS-STB-6** — Boot must never hang. Anything awaited before `runApp` must be
  local, bounded, and non-network (`AppBootstrapService`).
- **FS-STB-7** — Division, parsing, and date math on server data must handle
  null/zero/malformed input. Reps get real, messy SAP data.

---

## 4. Performance

- **FS-PRF-1** — `const` every widget that can be. It is free render savings.
- **FS-PRF-2** — Narrow rebuilds: `BlocSelector` or `buildWhen` over a bare
  `BlocBuilder` when only a slice of state matters. Never rebuild a page for a
  badge.
- **FS-PRF-3** — Long lists use `ListView.builder`/slivers with stable keys.
  Never `ListView(children: [...])` over unbounded data.
- **FS-PRF-4** — Prefer `MediaQuery.sizeOf(context)` over
  `MediaQuery.of(context)`. The latter subscribes to *every* metric change and
  rebuilds on keyboard show, rotation, and insets.
- **FS-PRF-5** — Images: `cached_network_image` for remote, explicit
  `cacheWidth`/`cacheHeight` for large assets. Never decode a 4K asset into a
  48pt avatar.
- **FS-PRF-6** — No I/O, JSON parsing, or crypto on the UI isolate for anything
  user-perceivable.
- **FS-PRF-7** — Keep `build()` cheap and side-effect free. No allocation of
  controllers, no network calls, no `DateTime.now()`-driven branching that
  forces rebuilds.
- **FS-PRF-8** — Animations must hold 60fps on the **oldest supported device**,
  not your laptop. Prefer opacity/transform over layout-affecting animation.

---

## 5. Responsive & adaptive

Foundation: `core/responsive/breakpoints.dart`, `responsive_sizing.dart`,
`responsive_content_frame.dart`. Full rationale in the responsive upgrade spec.

- **FS-RSP-1** — Layout decisions branch on **available width**, never on device
  type or OS. Banned as a layout signal: `Platform.isAndroid`, `Platform.isIOS`,
  device-model checks, `OrientationBuilder` alone.
- **FS-RSP-2** — Use the size classes, not raw numbers:
  ```dart
  context.windowSize          // compact | medium | expanded
  context.responsive(compact: 1, medium: 2, expanded: 3)
  ```
- **FS-RSP-3** — Every new dimension uses the responsive helpers, not bare
  ScreenUtil:
  ```dart
  height: context.rh(124)        // not 124.h
  width:  context.rr(48)         // not 48.r
  fontSize: context.rsp(14)      // not 14.sp
  padding: context.pagePadding   // not 16.w
  ```
  Compact returns the identical value, so the phone baseline never moves.
- **FS-RSP-4** — Grids derive column count from width
  (`SliverGridDelegateWithMaxCrossAxisExtent`). Hardcoded `crossAxisCount: N` is
  banned — except where N is semantic (a week has 7 days).
- **FS-RSP-5** — Text-heavy content and forms are width-clamped with
  `ResponsiveContentFrame`. Nothing runs edge-to-edge on a 1440pt window.
- **FS-RSP-6** — **Boundaries are hostile.** A breakpoint must not land on a real
  device. iPad Pro 12.9″ is 1024pt and the M5 13″ is 1032pt — which is exactly
  why side navigation keys off `Breakpoints.sideNavigationMin` (1440) and not
  `isExpanded` (≥1024). Verify new thresholds against actual device widths.
- **FS-RSP-7** — A tablet is not a stretched phone. If a layout gains only
  whitespace above 600pt, it is not adaptive yet.
- **FS-RSP-8** — Test at minimum: **390, 600, 834, 1032, 1280, 1440**. Include
  1032 — it is the width that has already broken twice.
- **FS-RSP-9** — One Bloc feeds all size classes. Never `PhoneBloc`/`TabletBloc`.

---

## 6. Animation & motion

Tokens exist — use them: `core/animations/app_animations.dart`.

- **FS-ANI-1** — Durations come from `AppDurations` (`fast` 150ms, `medium`
  250ms, `entrance` 350ms, `pressDown` 120ms, `pressUp` 180ms, `stagger` 40ms,
  `page` 320ms). No magic milliseconds.
- **FS-ANI-2** — Curves come from `AppCurves` (`standard`, `emphasized`,
  `pressDown`, `pressUp`). Never raw `Curves.linear` for UI motion.
- **FS-ANI-3** — Reuse the built primitives before writing new ones:
  `FadeSlideIn`, `PressScale`, `AnimatedCard`, `StaggeredList`,
  `ShimmerLoading`, `page_transition.dart`, `hero_transitions.dart`.
- **FS-ANI-4** — Motion must be **purposeful**: it explains a state change or
  spatial relationship. Decoration for its own sake is rejected.
- **FS-ANI-5** — Nothing blocks input. The user can always tap through or
  interrupt. No animation gates a business action.
- **FS-ANI-6** — Stagger caps out: at most ~6 items, ≤40ms apart. A 20-item
  staggered list feels broken, not premium.
- **FS-ANI-7** — Honour `MediaQuery.disableAnimationsOf(context)` /
  reduce-motion. Accessibility, and it makes tests deterministic.
- **FS-ANI-8** — Loading uses `ShimmerLoading` skeletons that match the real
  content's shape — never a bare centred spinner on a full screen.

---

## 7. Visual language — traditional + digital + premium

The brand is **Cambodian steel enterprise**: gold-accented, architectural,
confident. Premium means *restraint and precision*, not more effects.

- **FS-VIS-1** — **Material 3 only** (`useMaterial3: true`). No M2 patterns
  without a written reason.
- **FS-VIS-2** — Colors come from tokens: `context.appColors` (`card`, `canvas`,
  `surfaceSoft`, `surfaceStrong`, `border`, `divider`, `textPrimary`,
  `textSecondary`, `textHint`, `iconMuted`, `success`, `warning`, `info`,
  `brandNavy`, …) or `Theme.of(context).colorScheme`. **Never a raw hex in a
  feature widget.** New color ⇒ add a token.
  > The gold accent (`#F3E5AB → #D4AF37 → #996515`) is the traditional signature.
  > It belongs in a token, not copy-pasted per widget — it currently is, and
  > that is debt, not a pattern to follow.
- **FS-VIS-3** — Type comes from `Theme.of(context).textTheme` and
  `AppTypography`. Never `fontSize: screenWidth * 0.05`. Scale type through
  `context.rsp` only — never per-widget tuning.
  > **Revised on device.** This rule originally said type must scale *gently*
  > and slower than boxes. Reviewed on an iPad Pro 13" (1032pt), that produced
  > copy that read as too small twice over, so the type curve was raised 30%
  > (1.15→1.50 medium, 1.25→1.63 expanded) and now deliberately outruns
  > `boxScale`. The guard rail is **fit, not ratio**: if type ever ellipsizes a
  > label, give the box more room or allow a second line — never shrink the
  > type back. Enforced by the fit test in `responsive_sizing_test.dart`.
- **FS-VIS-4** — Both themes, always. Every new surface is checked in light
  **and** dark. Contrast ≥ 4.5:1 for body text.
- **FS-VIS-5** — Elevation and shadow are systematic. One shadow language per
  surface tier; no bespoke `boxShadow` stacks per card.
- **FS-VIS-6** — Corner radii, border widths, and gutters come from tokens.
  Visual consistency is the whole premium effect.
- **FS-VIS-7** — Iconography stays in one family and weight. No mixing filled,
  outlined, and rounded in the same view.
- **FS-VIS-8** — Every asset ships at the density it renders at, with a
  defined `errorBuilder`. A broken image must never become a broken layout.

---

## 8. Relaxed, calm UX

The user is a sales rep in a warehouse, on their feet, possibly offline,
often one-handed. Calm is a feature.

- **FS-UX-1** — **Four states, always**: loading, empty, error, content. An
  empty state explains what to do next; an error state offers a retry.
- **FS-UX-2** — Nothing shifts under the user's thumb. Reserve space for
  async content; no layout jump when data lands.
- **FS-UX-3** — Primary actions stay in comfortable reach on phones. Touch
  targets ≥ 48×48dp — including on tablets, where cursors and styluses also
  apply.
- **FS-UX-4** — Progressive disclosure: one primary action per screen. Density
  is earned by width (§5), never crammed.
- **FS-UX-5** — Destructive and irreversible actions confirm, and say what will
  happen in plain language. Offline actions state that they will sync later.
- **FS-UX-6** — Copy is calm and specific. No jargon, no blame, no exclamation
  marks. "Couldn't reach the server — saved on your device" beats "Error!".
- **FS-UX-7** — Never block on the network. Local write first, sync after
  (ADR-002). The UI confirms the local write immediately.
- **FS-UX-8** — Respect the back gesture and preserve scroll/tab/form state
  across navigation and rotation.

---

## 9. Localization (English + Khmer)

Not optional — Khmer is a first-class locale here.

- **FS-LOC-1** — Zero hardcoded user-facing strings. Every string is a key:
  `'shell.my_work'.tr`, `'x.y'.trParams({'count': 3})`.
- **FS-LOC-2** — Keys land in **both** `assets/lang/en.json` and `km.json` in
  the same PR. A missing Khmer key is a bug.
- **FS-LOC-3** — **Verify parameters actually substitute.** Shipping today:
  `~1 {minutes} min` and `GPS {dist} m away` render literally on the check-in
  screen. Assert interpolation in a test.
- **FS-LOC-4** — Khmer renders taller than Latin and does not break on spaces.
  Never constrain text with a fixed height; verify no clipping in `km`.
- **FS-LOC-5** — No string concatenation to build sentences — grammar differs.
  One key per full sentence.
- **FS-LOC-6** — Numbers, currency, and dates go through `intl`, not manual
  formatting.

---

## 10. Accessibility

- **FS-A11Y-1** — Interactive non-text elements carry `Semantics` labels.
- **FS-A11Y-2** — Layout survives **200%** system font scale without clipping
  or overflow. Fixed heights around text are the usual culprit.
- **FS-A11Y-3** — Color is never the sole carrier of meaning; pair with icon or
  text.
- **FS-A11Y-4** — Focus and hover states exist for pointer/keyboard input on
  large screens.
- **FS-A11Y-5** — `SafeArea` applied deliberately — status bar, Dynamic Island,
  home indicator, cutouts — without breaking intended edge-to-edge surfaces.

---

## 11. Long-term scale

- **FS-SCL-1** — Feature-first structure, strictly:
  `features/<name>/{data,domain,presentation}`. No new top-level concepts
  without an ADR.
- **FS-SCL-2** — **No feature imports another feature's `data/` layer.**
  Cross-feature flows go through domain interfaces or a shared orchestrator.
- **FS-SCL-3** — One use case = one business action. No `mode` parameter
  switching between unrelated behaviours.
- **FS-SCL-4** — All data access goes through a domain-defined repository
  interface returning **domain entities** — never Drift rows or DTOs.
- **FS-SCL-5** — Local reads/writes go through generated Drift DAOs. No feature
  holds a private database handle. No new `sqflite` usage — that migration is
  finishing, not expanding.
- **FS-SCL-6** — Register dependencies in `injection_container.dart`. No
  service locator calls buried in widget trees where they cannot be swapped in
  tests.
- **FS-SCL-7** — Assume 10× data. A list that works at 50 rows must work at
  5,000 — paginate or virtualize.
- **FS-SCL-8** — Before touching shared infrastructure, run
  `graphify affected "<symbol>" --depth 1` and state the blast radius in the PR.

---

## 12. Long-term maintenance

- **FS-MNT-1** — Comment the **why**, never the what. The best comments in this
  repo (see `app.dart`'s responsive-scaling note) explain a decision and what
  breaks without it. Match that bar.
- **FS-MNT-2** — Widgets stay small and single-purpose. A file over ~300 lines
  or a widget with more than one reason to change gets split.
  > `main_shell.dart` at 560+ lines with 9 cross-feature imports is the
  > cautionary example, not the template.
- **FS-MNT-3** — Name honestly. A `Manager` that resolves conflicts is a
  `ConflictManager`. Follow the corrections already made in
  `docs/skills/engineering-standard.md` §9.
- **FS-MNT-4** — Delete dead code. Do not comment it out — git remembers.
- **FS-MNT-5** — Every magic number becomes a named constant with a comment
  explaining its origin.
- **FS-MNT-6** — No copy-paste across features. Third occurrence ⇒ extract to
  `shared/widgets/` or `core/`.
- **FS-MNT-7** — When code and docs disagree, **fix or flag the doc in the same
  PR** (`docs/skills/engineering-standard.md` §11). Stale docs actively mislead both humans
  and AI agents.
- **FS-MNT-8** — Run `graphify update .` after structural changes so the graph
  stays queryable.

---

## 13. Next-generation upgrade readiness

- **FS-NXT-1** — No dependency on a package's internals or on a fork. If a
  package must be wrapped, wrap it behind an interface you own
  (`ConnectivityService` is the model).
- **FS-NXT-2** — Prefer Flutter's built-in APIs over third-party equivalents.
  Do not add a package for something `LayoutBuilder` or `MediaQuery` already
  does.
- **FS-NXT-3** — Isolate platform-specific code behind an abstraction so a new
  platform (desktop, web, foldable) is an implementation, not a rewrite.
- **FS-NXT-4** — No new deprecated API usage. Use `withValues(alpha:)`, not
  `withOpacity`. Clear deprecation warnings as you touch files.
- **FS-NXT-5** — Adding a dependency requires justification in the PR:
  what it does, why built-ins are insufficient, maintenance status, and licence.
- **FS-NXT-6** — Schema changes ship with a Drift migration **and** a migration
  test. Never a destructive migration on user data.
- **FS-NXT-7** — Server contracts are versioned and tolerant: unknown fields are
  ignored, missing optional fields do not crash the parser.
- **FS-NXT-8** — Design for the **rail-free tablet, foldables, and resizable
  windows** now — width-driven layout (§5) is what makes those free later.

---

## 14. PR checklist (copy into every PR)

```markdown
### Feature & UI Standard — docs/FEATURE_UI_STANDARD.md

**Blocking**
- [ ] `flutter analyze` — no new issues
- [ ] `flutter test` — passes; new Bloc has blocTest, new screen has widget test
- [ ] No secrets / PII / revenue in source or logs
- [ ] No hardcoded demo data (or tagged `// TODO(release-gate):` and listed below)
- [ ] Domain layer free of Flutter/Drift/dio imports
- [ ] Syncable writes enqueue in the same transaction

**Stability**
- [ ] `context.mounted` guarded after every await
- [ ] All controllers/subscriptions/listeners disposed
- [ ] Works offline; failures render a translated error state

**Performance**
- [ ] `const` applied; rebuilds narrowed (BlocSelector / buildWhen)
- [ ] Lists virtualized; `MediaQuery.sizeOf` not `.of`

**Responsive**  (tested at 390 / 600 / 834 / 1032 / 1280 / 1440)
- [ ] Uses `context.rh/rw/rr/rsp/pagePadding`, not bare ScreenUtil
- [ ] No `Platform.is*` or hardcoded `crossAxisCount` for layout
- [ ] No new breakpoint lands on a real device width
- [ ] Phone rendering verified unchanged

**Motion**
- [ ] `AppDurations` / `AppCurves` only; reduce-motion honoured

**Visual**
- [ ] Tokens only (`context.appColors`, `textTheme`) — no raw hex
- [ ] Verified in light and dark

**UX**
- [ ] Loading / empty / error / content states all present
- [ ] Touch targets ≥ 48dp; no layout shift

**Localization**
- [ ] Keys added to en.json AND km.json; params verified to interpolate
- [ ] Khmer checked for clipping

**Longevity**
- [ ] No feature imports another feature's data/
- [ ] New dependency justified (or none added)
- [ ] Migration + migration test for schema changes
- [ ] `graphify update .` run

**Blast radius:** <output of `graphify affected "<symbol>" --depth 1`>
**Release-gated TODOs:** <list, or "none">
**Screenshots:** phone + tablet, light + dark
```

---

## 15. Definition of Done

A feature is done when **all** are true:

1. It works on a 390pt phone and a 1032pt iPad, portrait and landscape.
2. It works offline, and says so calmly.
3. It works in English and Khmer, with no clipping and no literal `{param}`.
4. It works in light and dark.
5. It works at 200% font scale.
6. It has loading, empty, error, and content states.
7. It cannot crash from a failed request, a null field, or a disposed context.
8. It leaks no secrets and logs no PII.
9. It has tests, and `flutter analyze` is clean.
10. The next engineer can understand *why* from the code and the docs.

Anything less is a demo, not a feature.
