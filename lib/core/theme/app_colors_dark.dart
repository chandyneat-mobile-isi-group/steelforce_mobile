import 'package:flutter/material.dart';

/// Dark-theme raw color tokens — the dark-mode counterpart to
/// [AppColors] (lib/core/utils/colors.dart).
///
/// These are deliberately kept as a separate token set (rather than derived
/// on the fly) so the dark palette can be tuned by design independently of
/// light. They feed two consumers:
///  • the dark [ColorScheme] built in [AppTheme.dark], and
///  • the dark variant of the [AppThemeColors] theme extension, which carries
///    the semantic tokens (card, canvas, success, …) that don't map 1:1 to a
///    Material color role.
///
/// The palette keeps the ISI brand blue as the primary accent but lifts it a
/// little for legibility on dark surfaces, and follows Material 3 dark-surface
/// guidance (near-black elevated surfaces, ~87%/60% white text opacities).
class AppColorsDark {
  AppColorsDark._();

  // ── Brand / Primary ───────────────────────────────────────────────
  static const primary = Color(0xFF60A5FA); // lifted brand blue for dark bg
  static const primaryHover = Color(0xFF3B82F6);
  static const primaryLight = Color(0xFF1E3A5F); // tint bg for selected/active
  static const secondary = Color(0xFF93C5FD);
  static const secondaryLight = Color(0xFFBFDBFE);

  // ── Surfaces / Backgrounds ───────────────────────────────────────
  static const background = Color(0xFF0B1120); // main app background
  static const backgroundSoft = Color(0xFF111827); // secondary bg / sheets
  static const scaffoldBackground = Color(0xFF0B1120);
  static const surface = Color(0xFF161E2E); // card / sheet surface
  static const surfaceStrong = Color(0xFF1E3A5F); // primary-light tint surface
  static const surfaceContainer = Color(0xFF1C2536); // elevated container
  static const card = Color(0xFF161E2E);
  static const canvas = Color(0xFF0B1120); // home/shell scaffold background

  // ── Border / Divider / Shadow ─────────────────────────────────────
  static const border = Color(0xFF2A3444);
  static const divider = Color(0xFF222C3C);
  static const shadow = Color(0xFF000000);

  // ── Status ─────────────────────────────────────────────────────────
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const warningAlt = Color(0xFFFCD34D);
  static const error = Color(0xFFF87171);
  static const info = Color(0xFF38BDF8);

  // ── Text ───────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF3F4F6); // ~87% white
  static const textSecondary = Color(0xFF9CA3AF); // ~60% white
  static const textHint = Color(0xFF6B7280);
  static const textDisabled = Color(0xFF4B5563);
  static const textInverse = Color(0xFF0B1120); // on-primary/on-accent

  // ── Buttons ──────────────────────────────────────────────────────
  static const buttonPrimary = primary;
  static const buttonSecondary = surfaceStrong;
  static const buttonText = Color(0xFF0B1120);

  // ── Icons / Interaction states ────────────────────────────────────
  static const icon = Color(0xFFE5E7EB);
  static const iconMuted = Color(0xFF9CA3AF);
  static const selected = primary;
  static const unselected = Color(0xFF6B7280);
  static const overlay = Color(0xB3000000); // modal/scrim overlay

  // ── Legacy / secondary palette (dark counterparts) ─────────────────
  static const brandNavy = Color(0xFF3B82F6);
  static const brandNavyDark = Color(0xFF1E293B);
  static const accentPurple = Color(0xFFA78BFA);
  static const slate = Color(0xFFCBD5E1);
}
