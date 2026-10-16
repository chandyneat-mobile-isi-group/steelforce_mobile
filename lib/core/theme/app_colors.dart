import 'package:flutter/material.dart';

/// Single source of truth for every color used in the app.
///
/// This is the canonical token set — [lib/core/utils/app_vibe.dart]'s
/// `Vibe` (used by ~110 presentation files) and
/// [lib/core/theme/auth_vibe.dart]'s `Vibe` (used by the auth/splash/login
/// flow) both now delegate their constants to this file instead of
/// declaring their own hex literals, so a color only ever has one
/// definition. Both `Vibe` classes are kept as thin backward-compatible
/// facades — existing call sites (`Vibe.text`, `Vibe.violet`, ...) keep
/// working unchanged; new/updated code should reference [AppColors]
/// directly.
class AppColors {
  AppColors._();

  // ── Brand / Primary ───────────────────────────────────────────────
  //
  // Values are the ISI Group Brand Guide (WIP V1-R08) §07, not approximations
  // of it. Every colour below is quoted from that document with its Pantone
  // reference, so a future change is a question for the guide rather than a
  // matter of taste.
  //
  // Apex Blue is the *interactive* brand colour rather than Ironclad Blue,
  // which is the primary. Ironclad (#011E41) is near-black: correct for deep
  // surfaces and headings, unusable as a button fill, where it reads as
  // disabled rather than tappable. Ironclad is [brandNavy] below.
  static const primary = Color(0xFF004A98); // Apex Blue · Pantone 2945 C
  static const primaryHover =
      Color(0xFF00366E); // Apex Blue, dark tint (§07.02)
  // Foundational White as the selected/active tint: the guide's own neutral,
  // and the only light value it sanctions for backgrounds behind brand colour.
  static const primaryLight = Color(0xFFDCE3EB); // Foundational White · 656 C
  static const secondary = Color(0xFF4C82BA); // Apex Blue, light tint (§07.02)
  static const secondaryLight = Color(0xFF99AABF); // Ironclad, light tint

  // ── Surfaces / Backgrounds ───────────────────────────────────────
  static const background = Color(0xFFFFFFFF); // main app background
  static const backgroundSoft =
      Color(0xFFF8FAFC); // secondary background / sheets
  static const scaffoldBackground = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF); // card / sheet surface
  static const surfaceStrong = Color(0xFFDBEAFE); // primary-light tint surface
  static const card = Color(0xFFFFFFFF);
  // Foundational White (§07.05). The guide is explicit that this exists "to
  // calm down noise" behind the dominant colours, which is exactly what a
  // scaffold background is for.
  static const canvas = Color(0xFFDCE3EB); // Foundational White · Pantone 656 C

  // ── Border / Divider / Shadow ─────────────────────────────────────
  static const border = Color(0xFFE5E7EB);
  static const divider = Color(0xFFEDF2F7);
  static const shadow = Color(0xFF1F2937);

  // ── Status ─────────────────────────────────────────────────────────
  static const success = Color(0xFF2C9942); // Sustainable Green · 7739 C
  static const warning = Color(
      0xFFF59E0B); // canonical warning (existing "amber" token, 50+ call sites)
  static const warningAlt = Color(
      0xFFFBBF24); // legacy near-duplicate warning shade — see README note
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);

  // ── Text ───────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFF9CA3AF);
  static const textDisabled = Color(0xFF9CA3AF);
  static const textInverse = Color(0xFFFFFFFF);

  // ── Buttons ──────────────────────────────────────────────────────
  static const buttonPrimary = primary;
  static const buttonSecondary = primaryLight;
  static const buttonText = Color(0xFFFFFFFF);

  // ── Icons / Interaction states ────────────────────────────────────
  static const icon = Color(0xFF1F2937);
  static const iconMuted = Color(0xFF6B7280);
  static const selected = primary;
  static const unselected = Color(0xFF9CA3AF);
  static const overlay = Color(0x991F2937); // modal/scrim overlay
  static const transparent = Colors.transparent;

  // ── Legacy / secondary palette ─────────────────────────────────────
  // Colours that predate the token system and are still used verbatim by
  // the Home/Shell/Lead screens. NOTE: [brandNavy] is a *second* brand
  // blue distinct from [primary] — kept separate to preserve current
  // appearance until design confirms which is canonical.
  // Resolved against the brand guide. The note above asked which blue was
  // canonical; §07.01 answers it — Ironclad Blue is the primary brand colour,
  // and it belongs here rather than on [primary] for the contrast reason
  // explained at the top of this class.
  static const brandNavy = Color(0xFF011E41); // Ironclad Blue · Pantone 282 C
  static const brandNavyDark = Color(0xFF002169); // Dark Sapphire · 280 C
  // Brand Guide §07 secondary colour: the guide's one warm accent.
  static const brandBlaze = Color(0xFFE0592A); // Worksite Blaze · 7579 C
  static const accentPurple = Color(0xFF7C3AED);
  static const slate = Color(0xFF1E293B);
  // The gold accent of the SteelForce wordmark ("Steel" navy, "Force" gold)
  // and its underline, sampled from the approved guest-landing artwork.
  static const brandGold = Color(0xFFCF9611);

  static const double radius = 16.0;

  static const ctaGradient = LinearGradient(
    colors: [primary, primaryHover],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const coolGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft elevation used by flat enterprise cards (white bg + thin border).
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
