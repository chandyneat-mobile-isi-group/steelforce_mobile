// Encrypted file / attachment store — TRACKED INFRASTRUCTURE, NOT DEAD CODE.
//
// Planned: `docs/blueprint/migration-plan.md` §8 (Sprint-1-adjacent backlog) — P0, 5 pts.
//   AC: photos encrypted at rest; orphan cleanup on failed/abandoned uploads.
//
// Design constraints already locked:
//   • Media lives on the native filesystem; the database holds only string
//     references — never inline binary data in Drift.
//     (`docs/blueprint/system-architecture.md` §3 Layer 4, `docs/adr/ADR001singledatabase.md`)
//   • Growth is bounded by size caps + upload-then-purge TTL policy
//     (`docs/blueprint/sync-architecture.md` §11).
//
// Intentionally empty: per `docs/skills/engineering-standard.md` §2, no production code
// is written for a module until that module's plan and dependencies are
// validated and approved. This file marks the planned home so the stub is not
// mistaken for an unneeded feature (`.claude/CLAUDE.md`, playbook §12).
//
// Canonical name and location per `docs/blueprint/system-architecture.md` §5 target structure
// (`core/database/files/encrypted_file_store.dart`), replacing the historical
// typo `file_strorage.dart` (`docs/skills/engineering-standard.md` §9).
