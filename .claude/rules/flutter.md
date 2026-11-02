# Flutter & Dart

Conventions and the worked layering example: `docs/skills/ai-engineering-playbook.md`
§1–§2 and §13.

---

## 1. Prefer

- Small, focused, reusable widgets with a single responsibility.
- Business logic in BLoC/Cubit and usecases — never inside a widget's `build()`.
- Strong typing, null safety, `const` constructors wherever possible.
- Immutable models; `Equatable` for value equality (already a dependency).
- Centralised API handling, error handling, theming, and navigation.

## 2. Avoid

- Monolithic widgets. If `build()` does not fit on a screen, extract.
- Business logic, API calls, or database access inside widgets.
- Hardcoded API URLs, tokens, or secrets — see `security.md`.
- Duplicate API clients or duplicate models for the same payload.
- Global mutable state, and new dependencies when an existing one suffices.
- Copy-pasted implementations; extract the shared piece instead.

---

## 3. Error handling

Every API-driven screen handles four states explicitly:

| State | Requirement |
|---|---|
| **Loading** | A real loading affordance — never a blank screen |
| **Success** | The data |
| **Empty** | A clear "there is nothing here" message, distinct from error |
| **Error** | A useful, human message — **never** a raw exception or stack trace |

Technical detail goes to `core/logging/` (debug builds only), not to the user.
Use the existing failure/error types in `core/error/` rather than throwing
strings.

---

## 4. Performance

- No heavy work, allocation, or I/O in `build()`.
- No synchronous work on the UI thread that can block a frame.
- Lazy lists (`ListView.builder`) and pagination for anything unbounded.
- Scope rebuilds: `BlocBuilder` with `buildWhen`, `BlocSelector`, `const`
  subtrees. Do not rebuild a screen to update one badge.
- Use `cached_network_image` for remote images; size them.
- Cache and debounce; do not re-request the same data per rebuild.

Full guidance: `docs/skills/feature-ui-standard.md` §4 and
`docs/skills/ai-engineering-playbook.md` §9.

---

## 5. Formatting and analysis

```bash
dart format .
flutter analyze        # must be clean before any PR
```

Both run without asking. `flutter analyze` being clean is a gate, not a goal.
