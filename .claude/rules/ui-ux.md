# UI / UX

**Gate:** `docs/skills/feature-ui-standard.md` governs every feature, screen, and
UI upgrade — its §14 checklist goes in the PR. This file is the working summary.
Responsive depth: `docs/skills/responsive-and-adaptive-ui.md`.
Localization: `docs/skills/localization.md`. Brand: `docs/style-rule/`.

---

## 1. Visual language

This is a production enterprise app. It should read as **premium, calm,
professional, and legible at arm's length in daylight** — a rep uses it standing
in a steel yard.

**Avoid:** excessive gradients, 3D effects, glassmorphism, random colors,
oversized cards, over-rounded components, decorative animation, desktop layouts
squeezed onto a phone. Do not produce generic "AI-looking" interfaces.

**Prioritise:** clear hierarchy, honest spacing, readable type, touch-friendly
targets (≥48dp), consistent components, fast interaction.

Always use the existing design system — `lib/core/theme/app_theme.dart`,
`app_typography.dart`, `app_colors_dark.dart`, `theme_extensions.dart`. Never
hardcode a color, font size, or spacing value that the theme already defines,
and never invent a new visual language for one screen.

---

## 2. Responsive & adaptive

Design for real devices: small and large phones, tablets, Android and iOS, both
orientations, plus web (ADR-010).

- Use `lib/core/responsive/` — `breakpoints.dart`, `responsive_sizing.dart`,
  `responsive_content_frame.dart` — plus `MediaQuery`, `LayoutBuilder`,
  `Flexible`/`Expanded`, `SafeArea`. `flutter_screenutil` is available.
- **Do not branch on "phone vs tablet" as the primary layout strategy.** Branch
  on available width against the project breakpoints
  (`docs/skills/responsive-and-adaptive-ui.md` §4, §6).
- No unnecessary fixed dimensions. Respect safe areas and the keyboard inset.
- Constrain content width on wide screens rather than stretching a form edge to
  edge.

---

## 3. Motion

Motion clarifies state change; it does not decorate. Short, interruptible,
consistent easing; respect reduced-motion. Reusable pieces live in
`lib/shared/animations/` and `lib/core/animations/`. See
`docs/skills/feature-ui-standard.md` §6.

---

## 4. Localization (English + Khmer)

- **No user-visible hardcoded string.** Every string goes through the
  localization layer in `lib/core/localization/` with keys in
  `assets/lang/en.json` and `assets/lang/km.json` — both, in the same change.
- Khmer text is taller and longer than English: test every new screen in Khmer
  before calling it done. No fixed-height text containers.
- Master data that exists in both languages carries both — see
  `docs/skills/localization.md` §8.

---

## 5. Accessibility

Semantic labels on icon-only controls, ≥48dp targets, contrast that survives
sunlight, text that scales without clipping, and a focus order that makes sense.
`docs/skills/feature-ui-standard.md` §10.

---

## 6. Every screen handles four states

Loading · Success · **Empty** · Error — each designed, not improvised. An empty
list and a failed request must look different and say different things. See
`flutter.md` §3.
