# Features — per-feature implementation reference

> **Purpose:** how one specific feature works and where it is implemented.
> One directory per feature, named after its `lib/features/` folder.
> **Not here:** cross-cutting architecture ([../blueprint/](../blueprint/)),
> engineering rules ([../skills/](../skills/)), or business requirements
> ([../requirement/](../requirement/)).

Start with a feature's `README.md`. It answers: what is this, who uses it, what
screens belong to it, what APIs it calls, what state it manages, whether it
works offline, and where the code lives.

---

## Index

| Feature | `lib/features/` | Entry point | Coverage |
|---|---|---|---|
| **Authentication** | `authentication` | [authentication/README.md](authentication/README.md) | Full 15-document package — the reference standard for this directory |
| **Depot** | `depots` | [depot/README.md](depot/README.md) | API contract, UI/UX step design, SAP BP registration sub-package |
| **My Visits** | `my_visits` | [my-visits/README.md](my-visits/README.md) | Architecture, workflow, backend API proposal |
| **Order & Quotation** | `order` | [order/README.md](order/README.md) | Workflow, guided product selection, stock availability |
| **Notification** | `notification` | [notification/README.md](notification/README.md) | Full mobile integration guide (inbox, push, preferences, deep links) |
| **App Coach** | `app_coach` | [app-coach/README.md](app-coach/README.md) | Feature overview and interaction model |
| **Shell** | `shell` | [shell/README.md](shell/README.md) | UI upgrade plan (proposed, not started) |
| **Localization** | `localization` | [localization/README.md](localization/README.md) | Migration analysis; the how-to guide is [../skills/localization.md](../skills/localization.md) |
| **Geo location** | `geo_location` | [geo-location/README.md](geo-location/README.md) | Bundled offline gazetteer, tables, seeding, address selector |
| **Camera** | `core/camera` | [camera/README.md](camera/README.md) | The capture seam: real camera on a device, bundled test images on the iOS Simulator |

### Not yet documented

| Feature | `lib/features/` | Why it matters |
|---|---|---|
| Profile | `profile` | Rep identity surface and the sign-out path, which coordinates `SessionResetService`. |
| Home / KPI | `home`, `shell` | The landing dashboard every rep sees first. |
| Settings / Theme | `settings` | Theme-mode persistence. |
| About | `about` | About hub and informational pages. |

Ranked by cost of the gap: **profile first** — it owns the sign-out path, which
coordinates `SessionResetService`, and every feature holding rep-scoped data has
to register there or leak data across sessions. The rest are small surfaces
whose behaviour is legible from their code.

---

## Standard feature document set

Create only the documents that carry real information. An empty placeholder is
worse than an absent file — it implies coverage that does not exist.

| File | When to write it |
|---|---|
| `README.md` | **Always.** The entry point and index. |
| `overview.md` | When a non-engineer (PM, BA, QA, SAP team) needs the plain-language version. |
| `user-flow.md` | When the journey spans several screens non-obviously. |
| `workflow.md` | When there is a multi-step process with state. |
| `business-rules.md` | When rules are enforced in code and must be traceable. |
| `architecture.md` | When the feature's internal layering is non-trivial. |
| `ui-ux.md` | When screen structure, states (loading / empty / error / offline), or form behaviour need to be maintained deliberately. |
| `navigation.md` | When the feature adds routes or deep links beyond [../blueprint/navigation-architecture.md](../blueprint/navigation-architecture.md). |
| `state-management.md` | When the bloc/cubit topology is not obvious from the code. |
| `data-model.md` | When the feature owns Drift tables, Hive boxes, or secure-storage keys. |
| `api.md` | When it calls endpoints. Document only endpoints the client **actually** consumes. |
| `validation.md` | When validation rules are non-trivial or shared. |
| `offline-behavior.md` | When offline posture differs from [../blueprint/offline-architecture.md](../blueprint/offline-architecture.md). |
| `error-handling.md` | When failure mapping is feature-specific. |
| `security.md` | When the feature handles PII, credentials, or authorization. |
| `testing.md` | When there is a test plan beyond the standard tiers. |
| `diagram.md` | When a Mermaid diagram genuinely clarifies. Otherwise inline it. |

[authentication/](authentication/) is the worked example of the full set.

---

## Rules for this directory

1. **Directory name matches the code folder**, hyphenated:
   `lib/features/my_visits` → `docs/feature/my-visits/`.
2. **Never invent an endpoint.** If a contract is unknown, mark it unknown.
   `⧉ backend repo` marks a document that lives in the ISI API repository.
3. **One source of truth per subject.** Where two documents overlap, the more
   specific is authoritative and the other links to it.
4. **The code wins on what the app does.** Document divergence rather than
   silently "fixing" either side — see
   [../blueprint/README.md](../blueprint/README.md#known-documentation--code-divergences).
5. **No secrets.** No tokens, keys, certificates, or real depot data.
