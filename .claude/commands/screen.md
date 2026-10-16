---
description: Build or redesign a screen against the existing design system and UI standard
argument-hint: '<screen name and what should change>'
---

Screen work: **$ARGUMENTS**

**Gate:** `docs/skills/feature-ui-standard.md` governs this change. Read the
sections that apply before writing widget code, and put its §14 checklist in
your report.

## 1. Inspect the design system first — do not invent one

Read before designing:
- `lib/core/theme/` — `app_theme.dart`, `app_typography.dart`,
  `app_colors_dark.dart`, `theme_extensions.dart`
- `lib/core/responsive/` — `breakpoints.dart`, `responsive_sizing.dart`,
  `responsive_content_frame.dart`
- `lib/shared/widgets/` — what already exists that you should reuse
- Two or three comparable existing screens, for the established pattern

## 2. Build it

- Theme tokens only. No hardcoded color, font size, or spacing that the theme
  already defines.
- Branch on width against the project breakpoints — **never** on a
  "phone vs tablet" flag.
- `SafeArea`, keyboard inset, both orientations, and web.
- All four states designed: loading, success, **empty**, error — empty must look
  different from error.
- Every string localized in **both** `assets/lang/en.json` and `km.json`. No
  fixed-height text containers; Khmer runs taller.
- Semantic labels on icon-only controls; ≥48dp targets.
- Motion clarifies state change; it does not decorate.
- No business logic in the widget — it goes in the BLoC/Cubit and usecases.

## 3. Verify

```bash
dart format --set-exit-if-changed . && flutter analyze
flutter test test/features/<feature>/
```

Then have the **ui-ux-reviewer** agent review it, and report its findings.

## 4. Report

Summary · Files Changed · UI (what visibly changed) · Verification · Remaining
Issues (explicitly: which screen sizes, orientations, locales, and platforms you
did **not** check) · the §14 checklist.
