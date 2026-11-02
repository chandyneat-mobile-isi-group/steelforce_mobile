---
description: Integrate or change a backend endpoint against the documented contract
argument-hint: '<endpoint or capability to integrate>'
---

API work: **$ARGUMENTS**

Follow `.claude/rules/api-integration.md`.

## 1. Find the contract — do not guess it

```bash
graphify query "<feature> api datasource models"
```

Read, in order:
1. `docs/feature/<feature>/api.md` (or `api/mobile.md`) — the contract
2. `docs/skills/api-integration.md` — findings verified against the live API
3. `lib/core/network/` — the one client, envelope, error mapper, interceptor
4. The feature's existing `data/datasources/` and `data/models/`
5. Auth handling in `lib/features/authentication/` and `lib/core/session/`

**If the contract does not specify a field, stop and say exactly what needs
confirming.** Do not guess a field name — that ships as a production bug.

## 2. Implement

- Typed request/response models in `data/models/`; repository maps them to
  domain entities. No `Map<String, dynamic>` past the data layer.
- Errors map to `lib/core/error/` types. No `DioException` escapes `data/`.
- Reuse the existing client. No second `dio` instance, no parallel `http` path.
- Base URL and keys from Envied config only.
- Local-first: read from the database, then refresh. Writes go to the database
  **and** the sync queue in the same Drift transaction (ADR-006).
- Reachability via `connectivity_service.dart` (ADR-005).
- Never log tokens, PII, or full payloads.

## 3. Test

Success, empty, error, network failure, 401/unauthenticated, and offline. A
datasource tested only on 200 is not tested.

## 4. Report

Summary · Files Changed · **API** (endpoints, request/response shape, anything
unconfirmed from the contract) · Verification · Remaining Issues.
