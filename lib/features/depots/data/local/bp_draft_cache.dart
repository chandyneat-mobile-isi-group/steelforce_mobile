import 'dart:convert';

import 'package:steelforce/features/depots/data/mappers/bp_draft_json_mapper.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';

/// Stores the one registration form the rep currently has open.
///
/// ## Why Hive and not Drift
///
/// A draft is not a business record — it is UI state that happens to survive
/// the process. It has no schema anyone queries, it is thrown away the moment
/// the registration is accepted, and giving it a Drift table would mean a
/// migration every time the form grows a field. Layer 2, per ADR-009.
///
/// ## Why no TTL
///
/// [DepotReferenceCache] expires because a stale catalogue is wrong.
/// A stale draft is not wrong, it is unfinished — a rep who starts a
/// registration on Friday and returns to the shop on Monday must find their
/// typing intact. It is cleared on success, and only on success.
///
/// ## Why the encrypted box
///
/// The form carries depot names, owner and contact names, phone numbers, the
/// street address, tax numbers and GPS — customer PII, which `security.md` §2
/// forbids in the plain cache box. [_cache] must be backed by the AES-encrypted
/// `HiveService.secureBox`, whose key lives in platform secure storage.
///
/// Older builds wrote the draft to the plain box. [migrateLegacyPlaintext]
/// moves such a draft across and erases the plaintext copy; every read path
/// runs it too, so a draft can never be served from, or left in, plaintext.
///
/// ## Why exactly one
///
/// A single key, not a list. The wizard is modal and the rep can only be
/// standing in one shop at a time; a queue of half-filled forms would need a
/// picker, and the reliable outcome of that is a rep submitting the wrong one.
class BpDraftCache {
  const BpDraftCache(this._cache, {LocalCache? legacyPlaintext})
      : _legacy = legacyPlaintext;

  /// The encrypted store.
  final LocalCache _cache;

  /// The plain box an older build wrote to. Only ever read to migrate, then
  /// erased; never written.
  final LocalCache? _legacy;

  static const String _key = 'bp_registration_draft';

  /// Moves a draft left in the plaintext box by an older build into the
  /// encrypted one, then deletes the plaintext copy.
  ///
  /// Idempotent and cheap when there is nothing to move. A draft already in the
  /// encrypted store wins — it is newer than anything an older build left.
  /// The plaintext copy is deleted even when it cannot be migrated: keeping PII
  /// in the clear is worse than losing an unfinished form. Never throws.
  Future<void> migrateLegacyPlaintext() async {
    final legacy = _legacy;
    if (legacy == null) return;
    try {
      final raw = legacy.get<String>(_key);
      if (raw == null) return;
      final current = _cache.get<String>(_key);
      if (raw.isNotEmpty && (current == null || current.isEmpty)) {
        await _cache.set(_key, raw);
      }
    } on Object {
      // Fall through to the delete: an unreadable plaintext entry is still
      // plaintext.
    }
    try {
      await legacy.remove(_key);
    } on Object {
      // Retried on the next read.
    }
  }

  /// The saved form, or null when there is none or it cannot be read.
  ///
  /// A decode failure returns null **and clears the entry**. A draft written by
  /// an older build can be structurally unreadable, and leaving it in place
  /// would fail every subsequent open the same way — the rep would face a form
  /// that never loads and no way to reset it from the UI.
  Future<BpDepotDraft?> read() async {
    await migrateLegacyPlaintext();
    final String? raw;
    try {
      raw = _cache.get<String>(_key);
    } on Object {
      await clear();
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      return bpDraftFromJson(decoded.cast<String, dynamic>());
    } on Object {
      await clear();
      return null;
    }
  }

  /// Writes the form. Swallows failures on purpose — this is called on every
  /// keystroke's debounce, and an exception here would surface as the rep's
  /// typing throwing.
  Future<void> write(BpDepotDraft draft) async {
    try {
      // Encoded as a JSON string rather than a nested map: Hive round-trips
      // nested structures as `Map<dynamic, dynamic>`, and the cast back is
      // where this kind of cache usually starts throwing.
      await _cache.set(_key, jsonEncode(bpDraftToJson(draft)));
    } on Object {
      // Intentionally ignored. The form is still in memory and still correct;
      // the only thing lost is resume-after-kill, which is not worth an error
      // banner mid-sentence.
    }
  }

  Future<void> clear() async {
    try {
      await _cache.remove(_key);
      await _legacy?.remove(_key);
    } on Object {
      // Same reasoning as [write]. Worst case a stale draft is offered once
      // more and [read] discards it.
    }
  }

  /// True when there is something to resume. Used to decide whether the form
  /// should say so, rather than opening pre-filled with no explanation — which
  /// reads as a bug.
  bool get hasDraft {
    try {
      final raw = _cache.get<String>(_key);
      return raw != null && raw.isNotEmpty;
    } on Object {
      return false;
    }
  }
}
