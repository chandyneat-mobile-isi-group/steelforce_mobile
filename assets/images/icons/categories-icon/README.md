# Category icons — material catalogue

48 custom icons for the catalogue screens, drawn as one family. Nothing here comes from an
icon library.

```
categories-icon/
├── svg/                    96 files — <code>.svg + <code>_active.svg
├── tokens.css              colour, motion and surface tokens (light + dark)
├── preview.html            open this first: all 48, both themes, both sizes, states, motion
├── manifest.json           machine-readable index
└── flutter/                drop-in Dart integration
    ├── category_icon_tokens.dart
    ├── category_icons.dart
    ├── category_icon.dart
    └── pubspec.snippet.yaml
```

## The idea

The screens mix named steel products with material-master codes, and the codes carry two
facts at once: **what the material is** and **what stage it is at**. `RM-GL`, `SFG-GL` and
`RM-MH`, `SFG-MH`, `FG-MH` are the same material three times over. Drawing five unrelated
pictures for those would be noise.

So each icon is one glyph plus one badge:

| Badge | Stage | Used by |
|---|---|---|
| Open ring | Raw | `RM-*`, `Pre-Painted Coil (Raw)` |
| Half-filled | Semi-finished | `SFG-*`, the two semi-finished coils |
| Solid | Finished | `FG-*` |
| Diamond outline | Traded | the three `(Traded)` products |
| none | Catalogue product, part, fitting, supply | everything else |

The badge is knocked out of the glyph with an SVG mask, so the asset sits on any
background — white card, grey well, dark sheet — with no halo colour to maintain.

Stage is carried by **shape**, never by colour alone, so the whole set survives the
grayscale test (grayscale toggle in the preview).

## Drawing rules

| | |
|---|---|
| Grid | 24 × 24, content inside 21 × 21, badged glyphs scaled 0.87 |
| Stroke | 1.6 (1.75 active), round cap and join, no hairlines |
| Accent | Same colour as the stroke at 16% opacity, 30% when active |
| Corner radius | 1.0–2.6 depending on part size, never sharp unless the profile is sharp |
| Colour | One `currentColor` per icon — the file is monochrome duotone |
| Target | 48 px well with a 26 px glyph; legible down to 32 px |

Duotone-on-`currentColor` is the load-bearing decision: one file serves light mode, dark
mode, active and inactive. `flutter_svg` resolves `currentColor` through `SvgTheme`, so no
asset is duplicated per theme. The `_active.svg` files are provided for cases where you'd
rather swap an asset than drive state — they differ only in stroke weight and accent
opacity.

## Colour

Eight muted hues, one per catalogue family — desaturated enough to sit on screen all day.
Meaning comes from the glyph; colour only groups.

| Family | Light | Dark | Token |
|---|---|---|---|
| Named products | `#5B7089` | `#A9BACD` | `--cat-product` |
| RM — Raw material | `#4E7FB6` | `#8CB8E6` | `--cat-raw` |
| SFG — Semi-finished | `#3E8B82` | `#6FC3B9` | `--cat-semi` |
| FG — Finished goods | `#6470B4` | `#A3ABEE` | `--cat-finished` |
| FT — Fittings | `#4E8A62` | `#86C89C` | `--cat-fitting` |
| SP/MP/EP — Parts | `#96794A` | `#D6B47A` | `--cat-part` |
| GEN-SUPP — Supply | `#7A6AA6` | `#B4A7DD` | `--cat-supply` |
| Operational | `#6B7482` | `#A7B0BE` | `--cat-misc` |

## Motion

| Moment | Motion | Duration |
|---|---|---|
| Appear | fade + 0.96 → 1.0, 18 ms stagger across a grid | 300 ms, ease-out |
| Press | 1.0 → 0.96 → 1.0 | 140 ms, ease-out |
| Select | colour, well tint and stroke weight cross-fade | 220 ms, ease-in-out |
| Ambient | per-icon breath, float, pulse, twinkle or tick | 2.4–4 s |

**Ambient motion runs on the selected icon only.** A grid of 48 icons all breathing at once
is exactly the distraction the brief rules out, and it costs battery for nothing. Everything
respects `prefers-reduced-motion` / `MediaQuery.disableAnimations`.

No Rive, no Lottie. Scale and opacity on an SVG covers all of it.

## Flutter

```dart
// pubspec.yaml
dependencies:
  flutter_svg: ^2.0.10
flutter:
  assets:
    - assets/icons/categories/
```

Copy `svg/*.svg` to `assets/icons/categories/` and the three Dart files into your project.

```dart
// A single icon
CategoryIcon(code: 'rm-gl', active: selected == 'rm-gl');

// A catalogue tile, matching the current screens
CategoryTile(
  code: 'sfg-crc',
  active: selected == 'sfg-crc',
  onTap: () => setState(() => selected = 'sfg-crc'),
);

// Anywhere else — bottom nav, list row, empty state
SvgPicture.asset(
  specFor('fg-pt').asset,
  width: 24,
  theme: SvgTheme(currentColor: CategoryIconTokens.of(context, CategoryFamily.finished)),
);
```

Sizes: `sizeGrid` 26 in a 48 well, `sizeNav` 24, `sizeCompact` 20 in a 32 well.

## Reading of the codes — check these

Glyphs were drawn from this reading of the material master. Where a code was ambiguous I
took the common steel-industry meaning; tell me which are wrong and I'll redraw only those.

| Code | Read as |
|---|---|
| `MH` / `GH` | Mild hollow section / galvanized hollow section → square tube |
| `FG-SC` | Finished steel coil |
| `FG-CFP` | Cold-formed profile, light-gauge stud with service holes |
| `CM-COM` | Common consumable materials → sealed carton |
| `RM-STARCODE` | A branded grade → star over a code strip |
| `FT-SCHEIDER` | Schneider electrical gear → DIN-rail breaker module |
| `GEN-SUPP-OPER / HR-ADM / MRK` | Supplies by requesting function → shelf / personnel record / megaphone |
| `SERVICES` | Non-stock service line → signed work order |

## Full index

| Asset | Label | Family | Badge | Concept | Token | Ambient |
|---|---|---|---|---|---|---|
| `pipe` | Pipe | Named product | — | Round tube seen end-on: thin wall, open bore | `--cat-product` | Breath, 3.6s |
| `reinforcement-bar-traded` | Reinforcement Bar (Traded) | Named product | Diamond | Deformed bar drawn on the diagonal with three ribs | `--cat-product` | Breath, 3.6s |
| `cold-formed-sections` | Cold Formed Sections | Named product | — | C-section profile: the shape roll-forming produces | `--cat-product` | Breath, 3.6s |
| `galvanized-steel` | Galvanized Steel | Named product | — | Plate stack carrying the zinc spangle on its face | `--cat-product` | Twinkle, 3.2s |
| `profile-roofing` | Profile Roofing | Named product | — | Ribbed roofing panel seen along the slope | `--cat-product` | Float 0.6px, 4s |
| `i-beam-traded` | I-Beam (Traded) | Named product | Diamond | I-section cross-section, flange and web true to profile | `--cat-product` | Breath, 3.6s |
| `roofing-accessories` | Roofing Accessories | Named product | — | Ridge cap closed profile, fixed down with two screws | `--cat-product` | Float 0.6px, 4s |
| `h-beam-traded` | H-Beam (Traded) | Named product | Diamond | H-section, the I-beam rotated - reads as a pair | `--cat-product` | Breath, 3.6s |
| `steel-sheet` | Steel Sheet | Named product | — | Three flat plates stacked in isometric | `--cat-product` | Float 0.6px, 4s |
| `galvalume-steel-coil` | Galvalume Steel Coil | Named product | — | Coil with a shield mark for the Al-Zn coating | `--cat-product` | Breath, 3.6s |
| `pre-painted-coil-raw` | Pre-Painted Coil (Raw) | RM · Raw | Ring | Coil with a paint droplet for the colour-coated layer | `--cat-raw` | Breath, 3.6s |
| `rm-gi` | RM-GI | RM · Raw | Ring | Galvanized-iron coil, spangle mark | `--cat-raw` | Twinkle, 3.2s |
| `rm-gl` | RM-GL | RM · Raw | Ring | Galvalume coil, Al-Zn shield mark | `--cat-raw` | Breath, 3.6s |
| `rm-crc` | RM-CRC | RM · Raw | Ring | Cold-rolled coil: roller squeezed between two passes | `--cat-raw` | Breath, 3.6s |
| `rm-ss` | RM-SS | RM · Raw | Ring | Stainless plate with a mirror-polish band | `--cat-raw` | Twinkle, 3.2s |
| `rm-mh` | RM-MH | RM · Raw | Ring | Mild hollow section: square tube in isometric | `--cat-raw` | Breath, 3.6s |
| `rm-tile-adhesiv` | RM-Tile Adhesive | RM · Raw | Ring | Bagged tile adhesive, tile emblem on the sack | `--cat-raw` | Float 0.6px, 4s |
| `rm-starcode` | RM-STARCODE | RM · Raw | Ring | Branded grade: star above a code strip | `--cat-raw` | Twinkle, 3.2s |
| `galvanized-coil-semi` | Galvanized Coil (Semi-Finished) | SFG · Semi-finished | Half | Steel coil with a zinc-spangle star on the outer wrap | `--cat-semi` | Twinkle, 3.2s |
| `pre-painted-coil-semi` | Pre-Painted Coil (Semi-Finished) | SFG · Semi-finished | Half | Paint-droplet coil, half-stage badge | `--cat-semi` | Breath, 3.6s |
| `sfg-gs` | SFG-GS | SFG · Semi-finished | Half | Galvanized plate: spangle sitting on the face | `--cat-semi` | Twinkle, 3.2s |
| `sfg-gl` | SFG-GL | SFG · Semi-finished | Half | Galvalume coil at half stage | `--cat-semi` | Breath, 3.6s |
| `sfg-crc` | SFG-CRC | SFG · Semi-finished | Half | Cold-rolled coil at half stage | `--cat-semi` | Breath, 3.6s |
| `sfg-ss` | SFG-SS | SFG · Semi-finished | Half | Stainless plate at half stage | `--cat-semi` | Twinkle, 3.2s |
| `sfg-mh` | SFG-MH | SFG · Semi-finished | Half | Mild hollow section at half stage | `--cat-semi` | Breath, 3.6s |
| `sfg-oth` | SFG-OTH | SFG · Semi-finished | Half | Unspecified semi-finished stock: plate plus continuation dots | `--cat-semi` | Breath, 3.6s |
| `fg-sc` | FG-SC | FG · Finished | Solid | Finished steel coil, ready to ship | `--cat-finished` | Breath, 3.6s |
| `fg-mh` | FG-MH | FG · Finished | Solid | Mild hollow section, finished | `--cat-finished` | Breath, 3.6s |
| `fg-gh` | FG-GH | FG · Finished | Solid | Galvanized hollow section: same tube, spangle mark | `--cat-finished` | Twinkle, 3.2s |
| `fg-pt` | FG-PT | FG · Finished | Solid | Pipe and tube, finished | `--cat-finished` | Breath, 3.6s |
| `fg-cfp-light-gauge-steel` | FG-CFP Light Gauge Steel | FG · Finished | Solid | Light-gauge stud: C-section with service holes | `--cat-finished` | Breath, 3.6s |
| `ft-scheider` | FT-SCHEIDER | FT · Fitting | — | DIN-rail breaker module with its toggle | `--cat-fitting` | Pulse, 2.4s |
| `ft-board` | FT-BOARD | FT · Fitting | — | Distribution board with three breaker ways | `--cat-fitting` | Pulse, 2.4s |
| `ft-cable` | FT-CABLE | FT · Fitting | — | Cable spiralled onto itself, connector on the free end | `--cat-fitting` | Pulse, 2.4s |
| `ft-rf-screw` | FT-RF-SCREW | FT · Fitting | — | Hex-head roofing screw with washer and thread | `--cat-fitting` | Breath, 3.6s |
| `ft-tran-sheet` | FT-TRAN-SHEET | FT · Fitting | — | See-through panel: hollow face, hatched like glazing | `--cat-fitting` | Float 0.6px, 4s |
| `ft-oth` | FT-OTH | FT · Fitting | — | Hex nut - the generic fixing | `--cat-fitting` | Breath, 3.6s |
| `sp-mech` | SP-MECH | SP/MP/EP · Part | — | Single gear - mechanical spare part | `--cat-part` | Tick ±7°, 3.4s |
| `mp-mech` | MP-MECH | SP/MP/EP · Part | — | Two meshed gears - mechanical maintenance parts | `--cat-part` | Tick ±7°, 3.4s |
| `sp-elec` | SP-ELEC | SP/MP/EP · Part | — | Bolt glyph - electrical spare part | `--cat-part` | Pulse, 2.4s |
| `ep-elec` | EP-ELEC | SP/MP/EP · Part | — | Plug body and pins - electrical equipment part | `--cat-part` | Pulse, 2.4s |
| `gen-supp-oper` | GEN-SUPP-OPER | GEN-SUPP · Supply | — | Stock shelf - operational supplies held on site | `--cat-supply` | Breath, 3.6s |
| `gen-supp-hr-adm` | GEN-SUPP-HR-ADM | GEN-SUPP · Supply | — | Personnel record: document behind a person | `--cat-supply` | Breath, 3.6s |
| `gen-supp-mrk` | GEN-SUPP-MRK | GEN-SUPP · Supply | — | Megaphone - marketing and promotional supply | `--cat-supply` | Pulse, 2.4s |
| `cm-com` | CM-COM | Operational | — | Sealed carton in isometric - common consumables | `--cat-misc` | Float 0.6px, 4s |
| `scrap` | SCRAP | Operational | — | Offcut inside a return loop - material going back to melt | `--cat-misc` | Tick ±7°, 3.4s |
| `services` | SERVICES | Operational | — | Signed-off work order - a service, not a stocked item | `--cat-misc` | Breath, 3.6s |
| `others` | OTHERS | Operational | — | Four-dot grid - the catch-all bucket | `--cat-misc` | Breath, 3.6s |

Each row has a second file, `<asset>_active.svg`.
