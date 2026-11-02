# Profile

> **Status:** Draft · **Owner:** Mobile team · **Last reviewed:** 2026-10-24
> **Code:** `lib/features/profile/`

The rep's own identity screen: name, phone, avatar, and the **sign-out path**,
which coordinates `SessionResetService` so rep-scoped data does not leak into
the next session (`lib/core/session/`).

## Documents

| Document | What it covers |
|---|---|
| [api.md](api.md) | Profile and avatar API: reading and updating your own profile, uploading the avatar. ⧉ Written by the backend team (moved here from `authentication/` on 2026-10-24) |

## Code map

| Layer | Where |
|---|---|
| Data | `lib/features/profile/data/` (incl. `avatar_image_encoder.dart`) |
| Domain | `lib/features/profile/domain/` |
| Presentation | `lib/features/profile/presentation/` |
| DI | `lib/features/profile/profile_injection.dart` |

## Not documented yet

Screens, state and the sign-out sequence. This is the highest-priority gap in
[../README.md](../README.md#not-yet-documented): every feature holding
rep-scoped data depends on sign-out clearing it.
