# Performance

Day-to-day widget rules (`const`, `buildWhen`, lazy lists, no work in
`build()`) live in `flutter.md` §4. This file covers the rest: how to judge,
measure, and protect performance. Deeper guidance:
`docs/skills/feature-ui-standard.md` §4 and
`docs/skills/ai-engineering-playbook.md` §9.

The target device is a **mid-range Android phone on a weak or absent network,
in a steel yard, for a full working day.** Not a flagship on office Wi-Fi.

---

## 1. Measure, do not guess

- Never present a performance claim ("this is faster", "this fixes the jank")
  without a measurement. State the before and after numbers and how you got
  them.
- Profile in **profile mode** (`flutter run --profile`) on a physical device
  where possible. Debug-mode timings are meaningless; say so if a debug or
  emulator measurement is all you have.
- Tools: Flutter DevTools (Performance, CPU Profiler, Memory, Network),
  `debugProfileBuildsEnabled` for rebuild hunts, and
  `flutter build apk --analyze-size` / `flutter build ipa --analyze-size` for
  size.
- If you cannot run a device in this session, say so and give the user the
  exact measurement to take — do not optimise blind.

## 2. Budgets to defend

| Area | Expectation |
|---|---|
| Frames | Build + raster within the frame budget (16 ms at 60 Hz). No jank on scroll of any list screen. |
| Main isolate | No synchronous work that can exceed a few ms. JSON parsing of large payloads, PDF generation, image processing, and bulk sync mapping go to `Isolate.run` / `compute`. |
| Startup | Do the minimum before the first frame. Defer non-critical initialisation (analytics, prefetch, notification setup that is not needed for the first screen) until after it. Any new `main.dart` / bootstrap work needs a reason. |
| Memory | Remote images sized to their display (`memCacheWidth`/`cacheWidth`). Controllers, streams, and subscriptions disposed. No unbounded in-memory caches. |
| Database | Drift queries indexed for the filters screens use; paginate anything unbounded; batch writes inside one transaction. Watch for N+1 query loops. |
| Network | Never re-request per rebuild. Paginate, debounce, deduplicate in-flight requests, and respect the local-first rule (`api-integration.md` §3). |
| Battery | No polling where an event or sync trigger exists. GPS, camera, and background work only while needed, at the coarsest accuracy that serves the feature. |
| App size | Report the size impact of any new native SDK or large asset (`dependencies.md`). |

## 3. Background and lifecycle

- Respect `AppLifecycleState`: pause timers, location, and streams when
  backgrounded; resume deliberately.
- Background execution is limited and different on Android and iOS. Never
  assume a background task completes; design so the next foreground sync
  finishes the job (offline-first, ADR-002).

## 4. When you change a hot path

Hot paths: list screens, sync, startup, catalog search, and anything running
per item in a loop. For a change there:

1. Measure before.
2. Change one thing.
3. Measure after, same device, same build mode.
4. Report both numbers in **Verification**, or state plainly that you could
   not measure.
