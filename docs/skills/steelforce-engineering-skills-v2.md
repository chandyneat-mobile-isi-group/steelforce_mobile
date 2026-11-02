# SteelForce Engineering Skills: Clean Code, Reusable Components, and OOP

**Project:** SteelForce Flutter Mobile App\
**Audience:** Human developers and AI coding agents\
**Purpose:** Extend the existing AI Engineering Playbook without
replacing or contradicting the repository's architecture, ADRs,
security, offline-first, or API integration rules.

## How to apply these skills

Before changing code:

1.  Read `.claude/CLAUDE.md` and the existing AI Engineering Playbook.
2.  Inspect the target feature and nearby implementations before
    proposing new abstractions.
3.  Check existing shared components, utilities, repositories, use
    cases, models, and tests.
4.  Follow accepted ADRs and engineering standards when they conflict
    with a general recommendation in this document.
5.  Make the smallest complete change that solves the requested problem
    without changing unrelated behavior.

These rules apply to new code, refactoring, code reviews, and
AI-generated changes.

------------------------------------------------------------------------

# Skill 1 --- Clean Code and Safe Refactoring

## 1. Core principles

-   Prefer readable, explicit code over clever or compressed code.
-   Keep each class, method, and function focused on one clear
    responsibility.
-   Use meaningful names that communicate intent and domain meaning.
-   Keep business rules out of Flutter widgets and presentation-only
    code.
-   Avoid premature abstraction. Do not introduce a framework, base
    class, interface, or helper for a single trivial use unless it
    protects a real boundary or is required by architecture.
-   Preserve existing behavior during refactoring. Behavior changes must
    be identified, justified, and tested separately.
-   Follow the established feature-first Clean Architecture:
    `presentation → domain → data`.
-   Keep domain code independent of Flutter, Drift, Dio, and other
    infrastructure.
-   Prefer immutable entities and states, explicit null handling, and
    typed failures.
-   Do not use `dynamic` when a defined model or explicit type is
    possible.
-   Do not leave dead code, commented-out implementations, unexplained
    magic values, or swallowed exceptions.

## 2. Function and class design

-   A function should perform one cohesive task at one level of
    abstraction.
-   Extract a named private method when it makes a complex sequence
    easier to understand or test.
-   Avoid long parameter lists. Use a named parameter object when
    multiple values form one meaningful concept.
-   Keep constructors simple. Avoid constructors that perform network,
    database, or unrelated business operations.
-   A class should have one clear reason to change.
-   Avoid "manager", "helper", "handler", or "service" classes whose
    responsibilities are unclear or unlimited.
-   Do not create giant BLoCs, controllers, widgets, repositories, or
    utility classes.
-   Avoid boolean flags that make one method behave like several
    unrelated operations. Prefer explicit methods or well-named types
    when behavior differs substantially.

## 3. Error handling

-   Handle expected failures explicitly and map them to typed failures
    at the appropriate boundary.
-   Do not show raw exceptions, stack traces, tokens, personal
    information, or server internals to users.
-   Never silently swallow an exception with an empty `catch`.
-   Catch an exception only when the code can recover, add useful
    context, translate it, or safely rethrow it.
-   Logs must follow the project's redaction and security rules. Do not
    log credentials, tokens, personal identifiers, or sensitive business
    data.
-   Do not treat permission denial (403) as unauthenticated (401);
    follow the existing API integration contract.

## 4. Refactoring procedure

1.  Identify the current behavior and the intended scope.
2.  Inspect call sites, dependencies, tests, and related architecture.
3.  Make a small, behavior-preserving change.
4.  Avoid mixing unrelated feature work and refactoring in the same
    change.
5.  Add or update tests that protect the existing behavior.
6.  Run formatting, static analysis, and the relevant test suite.
7.  Report changed files, behavior impact, test results, and any
    remaining risks.

## 5. Clean-code review checklist

-   [ ] Names clearly communicate purpose.
-   [ ] Each function and class has a cohesive responsibility.
-   [ ] No business logic has been added to widgets.
-   [ ] No unnecessary duplication or premature abstraction was
    introduced.
-   [ ] Nullability and errors are handled explicitly.
-   [ ] No secrets or sensitive information are logged.
-   [ ] No unrelated behavior or public API changed unintentionally.
-   [ ] Tests cover the changed behavior and important edge cases.
-   [ ] `dart format` and `flutter analyze` pass without warnings.

------------------------------------------------------------------------

# Skill 2 --- Reusable Flutter Components

## 1. When to make a component reusable

Create a shared component when at least one of these is true:

-   The same UI pattern appears in multiple places and should stay
    visually consistent.
-   The component represents a stable design-system concept, such as a
    button, input, status badge, loading view, or empty state.
-   A complex widget can be isolated behind a clear interface and tested
    independently.
-   A repeated interaction or visual rule needs one reliable
    implementation.

Do not extract a component solely to reduce line count. A one-off widget
may remain local when abstraction would make it harder to understand.

## 2. Component ownership

Use the narrowest valid scope:

1.  **Local/private widget** --- used only in one screen or feature.
2.  **Feature component** --- shared within one feature, stored under
    that feature's presentation widgets.
3.  **Shared design-system component** --- used across unrelated
    features and intentionally maintained as a common UI contract.
4.  **Shared service/utility** --- for genuinely cross-feature behavior
    that is not UI-specific.

Do not put feature-specific business rules in `shared/widgets/`. Shared
widgets must not call DAOs, repositories, API clients, or feature BLoCs
directly.

## 3. Component API rules

-   Use descriptive names and strongly typed parameters.
-   Prefer required parameters for values the component cannot
    reasonably infer.
-   Use named parameters for public widget constructors.
-   Keep customization intentional; avoid exposing dozens of options
    "just in case."
-   Prefer composition and slots (`child`, `leading`, `trailing`, or a
    builder) when they make the component easier to adapt.
-   Use callbacks to communicate user intent, such as `onPressed` or
    `onChanged`.
-   Keep business decisions in the owning feature's BLoC/Cubit or use
    case.
-   Avoid hidden global state and implicit dependencies.
-   Define disabled, loading, error, empty, and accessibility behavior
    where relevant.
-   Follow the project's Material 3, localization, responsive layout,
    and light/dark theme conventions.
-   Use `const` constructors and widgets where possible.
-   Keep animations smooth and bounded; dispose controllers and
    subscriptions correctly.

## 4. Reuse without coupling

-   A shared component must not import a feature's `data/` or `domain/`
    implementation just to render UI.
-   Prefer generic presentation inputs (text, icon, status presentation
    model, callback) instead of accepting a large feature entity when
    only one or two fields are needed.
-   Do not duplicate API or database logic inside a widget.
-   Do not create parallel versions of an existing shared component
    without a clear reason.
-   Before creating a component, search the repository for an equivalent
    one and extend it if that is the safer choice.
-   Do not over-generalize unrelated screens into one component with
    many flags. Prefer a small set of cohesive components.

## 5. Example: reusable status badge

``` dart
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

This component owns presentation only. The feature decides the label and
color, including localized text and domain-status mapping.

## 6. Reusable component checklist

-   [ ] An existing component was searched for before creating a new
    one.
-   [ ] The component has a clear owner and appropriate folder.
-   [ ] Its public API is small, typed, and documented where needed.
-   [ ] It has no business logic, repository, DAO, or network
    dependency.
-   [ ] It supports required localization, theme, and responsive
    behavior.
-   [ ] It handles loading/disabled/error states when applicable.
-   [ ] It is accessible and testable.
-   [ ] Tests cover meaningful variants and interactions.
-   [ ] The abstraction reduces duplication without increasing coupling.

------------------------------------------------------------------------

# Skill 3 --- Object-Oriented Programming (OOP)

## 1. OOP purpose

Use OOP to model clear responsibilities and protect invariants, not
merely to create more classes. Prefer simple domain models and explicit
boundaries over deep inheritance trees.

## 2. Encapsulation

-   Keep implementation details private unless another part of the
    system genuinely needs them.
-   Expose behavior through methods that express intent, rather than
    exposing mutable internal state.
-   Protect domain invariants at the domain boundary.
-   Avoid public setters that allow invalid states to be created.
-   Keep database and API representation details out of domain entities.

**Preferred:** `depot.canTrade` or a domain method with a clear business
meaning.\
**Avoid:** allowing any screen to mutate several internal fields
independently and potentially create an invalid depot state.

## 3. Abstraction

-   Define an interface when it protects an architectural boundary,
    enables substitution/testing, or represents a meaningful contract.
-   In this project, repository interfaces belong in
    `domain/repositories/`; implementations belong in
    `data/repositories/`.
-   Keep interfaces small and focused on the consumer's actual needs.
-   Do not create interfaces for every class automatically.
-   Do not expose Drift rows, HTTP response objects, widgets, or
    framework-specific types through domain contracts.

## 4. Inheritance

-   Use inheritance only when the subtype genuinely satisfies the base
    type's contract and can safely replace it.
-   Avoid deep hierarchies and base classes with many optional
    overrides.
-   Do not use inheritance only to share a few lines of code; prefer a
    small helper or composition when clearer.
-   Do not override a method in a way that violates its documented
    expectations.
-   Favor final classes or sealed hierarchies where appropriate and
    compatible with the project's Dart version and architecture.

## 5. Polymorphism

-   Use polymorphism when multiple implementations should be usable
    through the same stable contract.
-   Example: a repository interface can have live and test
    implementations, while the feature depends only on the interface.
-   Keep implementation selection in dependency injection/configuration,
    not scattered throughout widgets.
-   Avoid repeated type checks and casts when a well-designed interface
    or sealed type can represent the variation.
-   Do not add multiple implementations just for theoretical future
    needs.

## 6. Composition over inheritance

Prefer composing an object from focused collaborators rather than
extending a large base class.

For example, a repository implementation may receive a database DAO, a
remote data source, and a mapper through constructor injection. It
should coordinate them without inheriting their responsibilities.

Benefits: - Dependencies are visible. - Collaborators can be tested
independently. - Responsibilities remain focused. - Implementations can
change without forcing a broad inheritance hierarchy.

## 7. SOLID rules for SteelForce

### S --- Single Responsibility Principle

A class should have one cohesive responsibility and one main reason to
change. Separate UI rendering, business decisions, persistence, network
access, and mapping.

### O --- Open/Closed Principle

Prefer extending behavior through an existing stable abstraction when a
genuine new variation appears. Do not introduce speculative extension
points before a need exists.

### L --- Liskov Substitution Principle

Every implementation of an interface must honor the same contract,
including error behavior, nullability, ordering, and offline
expectations. A mock must not pretend that rejected API writes always
succeed if production can reject them.

### I --- Interface Segregation Principle

Consumers should depend only on operations they need. Split large
interfaces when they force unrelated consumers to implement unused
methods, but do not split a small cohesive contract without a reason.

### D --- Dependency Inversion Principle

High-level domain rules should depend on domain abstractions, not
low-level infrastructure. Use the existing dependency-injection setup;
do not instantiate concrete repositories, databases, or HTTP clients
inside widgets or use cases.

## 8. OOP and Clean Architecture boundaries

Follow the project's existing direction:

`Presentation → Domain ← Data implementations`

-   **Presentation:** widgets and BLoC/Cubit. Render state and dispatch
    intent; do not access DAOs or repositories directly.
-   **Domain:** immutable entities, repository contracts, use cases,
    domain rules, and typed domain failures. No Flutter, Drift, or Dio
    imports.
-   **Data:** API/local data sources, DTOs, Drift models, mappers, and
    repository implementations.
-   **Dependency injection:** compose implementations at the existing DI
    boundary.
-   **Shared UI:** reusable presentation only; no business logic.

For any syncable write, preserve the existing project rule that the
local mutation and sync-queue enqueue occur in the same database
transaction. Do not bypass established repository or offline-first rules
in the name of OOP.

## 9. OOP example: repository abstraction

``` dart
abstract interface class DepotRepository {
  Future<Depot?> getById(String id);
}

final class GetDepotById {
  const GetDepotById(this._repository);

  final DepotRepository _repository;

  Future<Depot?> call(String id) => _repository.getById(id);
}
```

The data layer implements `DepotRepository`. The use case depends on the
contract and does not know whether data came from local storage, an API,
or a test implementation. Adapt syntax to the Dart SDK already used by
the repository.

## 10. OOP review checklist

-   [ ] Each class has a clear responsibility.
-   [ ] Internal state and invariants are protected.
-   [ ] Abstractions exist for real boundaries, not as ceremony.
-   [ ] Inheritance models a genuine substitutable relationship.
-   [ ] Composition is preferred when it keeps responsibilities clearer.
-   [ ] Implementations honor the same interface contract.
-   [ ] Dependencies are injected at appropriate boundaries.
-   [ ] Domain code is independent of infrastructure.
-   [ ] No unnecessary base classes, interfaces, factories, or design
    patterns were added.

------------------------------------------------------------------------

# Shared AI Coding-Agent Rules

When implementing a task in SteelForce, the coding agent must:

1.  Inspect existing code and reuse established patterns before
    designing new ones.
2.  State the intended scope and files likely to change before a broad
    refactor.
3.  Follow the current architecture, accepted ADRs, API contracts,
    offline-first rules, security requirements, and naming standards.
4.  Avoid unrelated cleanup or broad rewrites.
5.  Never claim tests passed unless they were actually run and passed.
6.  Add or update tests for changed behavior and important edge cases.
7.  Run `dart format` and `flutter analyze`; run relevant unit, widget,
    integration, database, and contract tests as applicable.
8.  Check for duplicated components, duplicate dependency registrations,
    direct infrastructure access from presentation, and cross-feature
    data-layer imports.
9.  Preserve existing user-visible behavior unless the task explicitly
    requires a change.
10. Report:

-   What changed and why
-   Files/components affected
-   Tests and commands actually run
-   Any known limitation, unresolved requirement, or release-gate TODO

## Final Definition of Done

A change is ready only when:

-   The implementation meets the requested behavior.
-   The design is no more complex than necessary.
-   Architecture and OOP boundaries are respected.
-   Reuse is deliberate and does not introduce coupling.
-   Error handling, null safety, security, and offline behavior remain
    correct.
-   Relevant tests pass, or unrun/failed tests are explicitly reported.
-   Formatting and static analysis are clean, or any existing blocker is
    documented.
-   Documentation is updated when the change affects a contract,
    architectural decision, or operational workflow.

------------------------------------------------------------------------

# Skill 4 — File Size and Complexity Limits

## 1. Purpose

Keep files easy to understand, review, test, and safely change as SteelForce grows. Line limits are review signals, not a reason to split code mechanically. Preserve cohesive responsibilities and avoid creating many tiny files that make navigation harder.

## 2. Recommended line limits

Count non-blank source lines as a useful secondary measure, but use total file lines for consistent automated checks. Exclude generated files, localization output, lockfiles, and other machine-generated artifacts from these limits.

| File type | Preferred target | Review/refactor threshold | General rule |
|---|---:|---:|---|
| Stateless/stateful UI widget file | ≤ 250 lines | > 300 lines | Split cohesive subwidgets or move feature-specific widgets to their own files. |
| Screen/page file | ≤ 300 lines | > 400 lines | Keep the screen as composition and state rendering; extract sections and complex interactions. |
| Controller, BLoC, or Cubit | ≤ 250 lines | > 300 lines | Separate unrelated state transitions and delegate business operations to use cases. |
| Use case / application action | ≤ 150 lines | > 200 lines | One clear business action per use case; split only when responsibilities are distinct. |
| Repository implementation | ≤ 300 lines | > 400 lines | Separate data sources or mapping responsibilities where architecture permits. |
| Data source / API client | ≤ 250 lines | > 350 lines | Keep endpoint groups cohesive and avoid mixing transport with business rules. |
| Domain entity / model | ≤ 200 lines | > 300 lines | Keep domain invariants together; separate unrelated concepts. |
| Mapper / serializer | ≤ 200 lines | > 300 lines | Split by model or domain boundary when it improves clarity. |
| Shared UI component | ≤ 200 lines | > 250 lines | Keep the API small and the component presentation-only. |
| Utility / extension file | ≤ 150 lines | > 200 lines | Group by one cohesive purpose; avoid giant miscellaneous utility files. |
| Test file | ≤ 400 lines | > 500 lines | Split by behavior or scenario while keeping tests discoverable. |

These are default engineering targets, not absolute compiler errors. A file exceeding a threshold must be reviewed and either refactored or documented with a short reason. Do not split a file if doing so would obscure a cohesive concept or create artificial abstractions.

## 3. Complexity rules

- A class must have one cohesive responsibility and a clear owner.
- Keep functions focused; aim for approximately 40 lines or fewer for ordinary functions. Longer functions require a readability review, not automatic extraction.
- Avoid deeply nested control flow. Prefer early returns and small, named methods when they make intent clearer.
- Avoid very long parameter lists; use a typed parameter object when the values form a meaningful concept.
- Do not create a generic `utils.dart`, `helpers.dart`, or `manager.dart` as a dumping ground.
- Do not split code solely to satisfy a line count. Split by responsibility, feature, or stable abstraction.
- Keep public APIs small and typed; document non-obvious contracts.
- Never move business rules into UI widgets merely to reduce file size.

## 4. Suggested feature-first file layout

Follow the existing repository layout and accepted ADRs. A feature may use a structure such as:

```text
features/
  visits/
    presentation/
      pages/
        visit_list_page.dart
      widgets/
        visit_card.dart
        visit_filter_bar.dart
      state/
        visit_cubit.dart
        visit_state.dart
    domain/
      entities/
        visit.dart
      repositories/
        visit_repository.dart
      use_cases/
        get_visits.dart
    data/
      data_sources/
        visit_remote_data_source.dart
      models/
        visit_dto.dart
      mappers/
        visit_mapper.dart
      repositories/
        visit_repository_impl.dart
```

Treat this as an example only. Reuse the actual state-management, dependency-injection, naming, and folder conventions already used by the project. Do not reorganize unrelated features as part of a small task.

------------------------------------------------------------------------

# Skill 5 — Smooth UI and Runtime Performance

## 1. Rendering and rebuilds

- Keep `build()` methods fast, deterministic, and free of network, database, file, or expensive synchronous work.
- Use `const` constructors and immutable widget inputs wherever possible.
- Split widgets at meaningful state and responsibility boundaries so a small state change does not rebuild an unnecessarily large screen.
- Use `ListView.builder`, `SliverList`, or the appropriate lazy builder for large or unbounded collections; do not eagerly build every row.
- Provide stable, meaningful keys when list item identity matters, especially when items can be inserted, removed, reordered, or updated.
- Avoid unnecessary rebuilds caused by broad state subscriptions. Select or listen to only the state needed by each widget, using the project's existing state-management approach.
- Do not add `RepaintBoundary` everywhere. Add it only when profiling indicates that isolating repaint work helps.
- Avoid expensive layout patterns, repeated intrinsic measurements, and deeply nested layouts in scrolling lists unless necessary.
- Cache derived presentation values when computation is genuinely expensive; do not add caches for trivial expressions without evidence.

## 2. Asynchronous work and responsiveness

- Keep network requests, database operations, image processing, and other I/O asynchronous.
- Never use blocking waits or synchronous heavy computation on the UI isolate.
- Debounce rapid search/filter input when appropriate, cancel or ignore stale requests, and prevent duplicate submissions where required.
- Show intentional loading, empty, error, and retry states instead of leaving the UI frozen or blank.
- Use pagination or incremental loading for large API-backed collections where supported by the API contract.
- Dispose `AnimationController`, `TextEditingController`, `ScrollController`, stream subscriptions, and other owned resources correctly.
- Avoid unnecessary timers, animation loops, listeners, and repeated polling. Stop them when no longer needed.
- Use isolates or Flutter-supported background processing only when profiling shows CPU-heavy work is affecting frame times.

## 3. Images, lists, and animation

- Request appropriately sized images and use caching according to the existing image and privacy policies.
- Avoid decoding full-resolution images for small thumbnails. For local image workflows, resize/compress deliberately without degrading required evidence quality.
- Use bounded, purposeful animations; avoid animating expensive layout properties when a cheaper transform or opacity animation is suitable.
- Respect reduced-motion/accessibility expectations where the app's conventions support them.
- Avoid rebuilding every item in a list when only one item changes.
- Test long text, large datasets, slow networks, empty responses, and small-screen layouts.

## 4. Performance verification

- Measure before optimizing; do not claim an optimization improved performance without evidence.
- Reproduce issues in profile mode on representative devices. Debug-mode timing alone is not a reliable performance benchmark.
- Inspect Flutter DevTools frame rendering, widget rebuilds, memory, and network activity when investigating jank or slow screens.
- For smooth 60 Hz rendering, use approximately 16.7 ms per frame as a practical frame-budget reference; higher-refresh devices have a tighter budget.
- Check for memory growth after repeated navigation, opening/closing screens, and starting/stopping subscriptions.
- Record the scenario, device/mode, observed bottleneck, and before/after result for significant performance work.
- Prefer performance tests or repeatable manual checks for critical flows rather than unsupported claims such as “fast” or “optimized.”

------------------------------------------------------------------------

# Skill 6 — Scalable Architecture and Dependency Boundaries

## 1. Feature ownership

- Organize code around business features and stable architectural boundaries, following the existing SteelForce structure.
- Each feature should own its screens, state, domain rules, data access, and tests unless a concept is intentionally shared.
- Keep cross-feature dependencies explicit and minimal. Do not import another feature's internal data implementation to reuse a model or helper.
- Promote code into shared modules only when it is genuinely generic, stable, and useful across features.
- Avoid circular dependencies between features or layers.

## 2. Dependency direction

Maintain the existing Clean Architecture direction:

`Presentation → Domain ← Data implementations`

- Presentation renders state and sends user intent; it does not call DAOs or HTTP clients directly.
- Domain defines business rules, entities, repository contracts, and typed failures without Flutter or infrastructure dependencies.
- Data implements domain contracts and owns API/local-storage details, DTOs, and mapping.
- Register dependencies through the project's established dependency-injection boundary.
- Avoid service locators or global mutable state scattered throughout feature code.
- Add an abstraction only when it protects a meaningful boundary, enables substitution/testing, or expresses a stable contract.

## 3. State, API, and offline-first safety

- Preserve existing API contracts, authorization behavior, security rules, and offline-first behavior during refactoring.
- Keep UI state separate from persistence models and API DTOs where the architecture requires it.
- Represent loading, success, empty, and failure states explicitly using the project's established patterns.
- Use pagination, filtering, and server-side querying when appropriate instead of loading unbounded datasets into memory.
- For syncable writes, preserve the established rule that the local mutation and sync-queue enqueue happen in the same database transaction.
- Do not make a mock or fallback implementation silently report success when production can reject the operation.
- Avoid duplicate requests and duplicate dependency registrations; ensure subscriptions and listeners have clear ownership.

## 4. Testing and change safety

- Add unit tests for domain rules and use cases, repository tests for data mapping/error behavior, and widget tests for meaningful UI states and interactions.
- Add regression tests when fixing a bug or changing a public contract.
- Test error, empty, loading, offline, retry, and permission-denied cases where relevant.
- Keep test names focused on observable behavior rather than implementation details.
- Prefer small, reviewable changes. Do not combine broad architectural rewrites with unrelated feature work.
- Update documentation and architecture decision records when a change materially changes a contract or boundary.

------------------------------------------------------------------------

# Skill 7 — Automated Quality Gates

## 1. Required checks

Before a change is considered ready, run the checks supported by the repository and report their actual outcomes:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Run targeted tests during development, then the relevant broader suite before merging. If a command is not applicable, cannot run, or fails because of an existing environment issue, state that explicitly. Never report a check as passing unless it was executed successfully.

## 2. File-length enforcement

- Add a lightweight CI or pre-commit check for file-length thresholds only after confirming generated files and repository conventions are excluded correctly.
- Treat threshold violations as a review warning initially; promote selected limits to hard failures only after the team agrees and existing violations are understood.
- Do not fail builds for generated files, lockfiles, snapshots, or vendored code.
- A justified exception should name the file, explain why splitting would reduce clarity, and be revisited when the file changes substantially.

## 3. Definition of Done additions

- [ ] Source files remain within the preferred line targets, or exceptions are justified.
- [ ] Large files and complex functions were reviewed for cohesive extraction.
- [ ] UI rendering contains no blocking or expensive I/O work.
- [ ] Large lists use lazy rendering where appropriate.
- [ ] State subscriptions, controllers, and animations have correct lifecycle cleanup.
- [ ] No new circular dependencies or architecture-boundary violations were introduced.
- [ ] Performance claims are supported by profiling or a repeatable test.
- [ ] Formatting, analysis, and relevant tests were run and their actual results reported.

