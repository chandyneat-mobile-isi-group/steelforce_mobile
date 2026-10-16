# State management

Authoritative: `docs/skills/engineering-standard.md` §4. Stack: `flutter_bloc`
(8.x) with `bloc_concurrency`, plus `equatable`.

---

## 1. Before adding any new BLoC/Cubit

1. Search the feature — the state you need often already exists.
2. Match the existing pattern in that feature. Do not introduce a second state
   solution (no Provider, Riverpod, `setState`-driven business logic, or
   `ChangeNotifier`) alongside BLoC.
3. Prefer **Cubit** for simple state; use **BLoC** when you genuinely need
   events (replay, concurrency control, transformers).

---

## 2. State modelling

Model the four states explicitly — never one nullable field plus a bool:

```dart
sealed class DepotListState extends Equatable { … }
class DepotListInitial  extends DepotListState {}
class DepotListLoading  extends DepotListState {}
class DepotListLoaded   extends DepotListState { final List<Depot> depots; }
class DepotListEmpty    extends DepotListState {}
class DepotListFailure  extends DepotListState { final Failure failure; }
```

- States are immutable and `Equatable` — otherwise `BlocBuilder` cannot skip
  rebuilds.
- A BLoC depends on **usecases**, never on a repository implementation, a DAO,
  or `dio` directly.
- Keep presentation concerns (strings, colors, formatting) out of state. State
  carries domain data; the widget renders it and localizes it.

---

## 3. Concurrency

Use `bloc_concurrency` transformers deliberately: `droppable()` for a submit
button, `restartable()` for search-as-you-type, `sequential()` for ordered
writes. An un-transformed handler on a rapidly fired event is a bug.

---

## 4. Rebuild discipline

- `buildWhen` / `BlocSelector` to narrow rebuilds.
- Put the `BlocBuilder` as deep in the tree as possible, not at the screen root.
- Never call `emit` after `close()`; guard long async work with `isClosed`.

---

## 5. Lifecycle and data hygiene

Dispose subscriptions and controllers. Any BLoC holding rep-scoped data must
register with `SessionResetService` so sign-out clears it — otherwise data leaks
across sessions. See `lib/core/session/`.
