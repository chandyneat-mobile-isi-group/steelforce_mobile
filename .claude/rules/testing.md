# Testing

Authoritative matrix and coverage gates:
`docs/skills/engineering-standard.md` §10. QA assets (test cases, scenarios,
device matrix, release checklist): `QA-engineering/`.

---

## 1. Coverage gates (CI-enforced)

| Layer | Gate |
|---|---|
| domain | ≥ 90% |
| data | ≥ 80% |
| cryptography, sync-queue | **100% of branches** |

---

## 2. Pick tests by what you changed

| Changed | Required tests |
|---|---|
| Domain logic / usecase | Unit tests |
| Repository | Repository tests (with a faked datasource) |
| Drift DAO or table | DAO/database tests **+** `build_runner` |
| Sync, queue, conflict | Sync + conflict + offline tests |
| Security, auth, crypto | Security tests **+ negative paths** |
| UI / widget | Widget tests; golden tests where a layout is worth locking |
| Cross-layer | Integration tests |

Every test set covers the normal flow **and** the failure paths: loading, empty,
error, API failure, offline, and unauthenticated where applicable. A feature
tested only on its happy path is not tested.

---

## 3. Commands

```bash
flutter test                                    # unit + widget
flutter test test/features/<feature>/           # targeted — start here
flutter test integration_test/
dart run build_runner build --delete-conflicting-outputs
```

Run the targeted suite first, then broaden (`workflow.md` §6). Run them without
asking.

---

## 4. Honesty

- Report the real result, including failures, with the output.
- A compiling app is not a verified app.
- If you could not run something — no device, no emulator, a missing fixture —
  say exactly that in **Remaining Issues**. Do not imply it passed.
