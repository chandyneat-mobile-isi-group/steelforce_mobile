# Flutter Professional Responsive & Adaptive UI Upgrade

> ### About this document
>
> This is the **audit brief** that produced the responsive/adaptive work in this
> app, kept verbatim because its requirement list is the most complete statement
> of what "responsive" means here. It is written in the second person ("You are
> a…", "I want you to…") because it was authored as a specification handed to an
> engineer.
>
> **The enforceable rules are [feature-ui-standard.md](feature-ui-standard.md)
> §5**, which gates every PR. Use this document for the full requirement
> inventory and the reasoning; use the standard for what actually blocks a merge.
> Breakpoints and helpers live in `lib/core/responsive/`.


You are a **Senior Flutter Architect, UI/UX Engineer, and Responsive/Adaptive Design Specialist**.

I want you to perform a complete audit and upgrade of my existing Flutter application so that it provides a professional, consistent, modern, and adaptive experience across:

1. Android phones
2. iPhones
3. Android tablets
4. iPads

The objective is NOT to create four completely separate applications.

The objective is to create **one scalable Flutter codebase with adaptive layouts** that automatically provides the best UI for the available screen space.

---

# 1. IMPORTANT: RESEARCH BEFORE IMPLEMENTATION

Before modifying the project, inspect the current Flutter project and review the latest official Flutter guidance for:

- Adaptive UI
- Responsive UI
- Large-screen support
- Tablet layouts
- iPad layouts
- Android large screens
- Foldables
- Multi-window
- Safe areas
- Material 3
- NavigationBar
- NavigationRail
- NavigationDrawer
- LayoutBuilder
- MediaQuery.sizeOf
- SliverLayoutBuilder
- Accessibility
- Keyboard/mouse/stylus input

Prefer official Flutter and Material documentation.

Do NOT rely on outdated responsive-design assumptions.

Do NOT blindly introduce a third-party responsive package if Flutter's built-in APIs can solve the problem cleanly.

---

# 2. FIRST: AUDIT THE EXISTING PROJECT

Before changing code, inspect the complete repository.

Analyze:

- Flutter version
- Dart version
- pubspec.yaml
- Project structure
- Feature structure
- Existing UI architecture
- BLoC/Cubit implementation
- Routing
- Theme system
- Localization
- Reusable widgets
- Screen implementations
- Existing responsive utilities
- Existing ScreenUtil or similar packages
- Hardcoded widths
- Hardcoded heights
- Hardcoded padding
- Hardcoded font sizes
- Fixed-size containers
- Overflow risks
- Row/Column layout problems
- Nested scrolling problems
- Grid implementations
- Navigation implementation
- Dialogs
- Bottom sheets
- Forms
- Tables
- Cards
- Lists
- Empty states
- Loading states
- Error states

Search the entire codebase for problematic patterns such as:

- MediaQuery.of(context).size
- MediaQuery.of(context).orientation
- OrientationBuilder
- hardcoded device checks
- Platform.isAndroid
- Platform.isIOS
- hardcoded screen widths
- hardcoded screen heights
- excessive SizedBox dimensions
- fixed Container widths
- fixed Container heights
- excessive Expanded
- excessive Flexible
- Row overflow risks
- Text overflow risks
- fixed GridView column counts
- portrait-only assumptions
- unnecessary SystemChrome orientation locks

Do NOT immediately rewrite everything.

First understand the existing architecture.

---

# 3. RESPONSIVE VS ADAPTIVE DESIGN

Use these concepts correctly.

## Responsive

Responsive design means the UI changes its sizing, spacing, positioning, and composition according to the available space.

Examples:

- 1-column layout on narrow screens
- 2-column layout on medium screens
- 3+ column layout on wide screens
- Flexible card widths
- Responsive padding
- Responsive typography
- Constrained content width

## Adaptive

Adaptive design means the application can change the UI structure when the available space requires it.

Examples:

Small width:
- Bottom Navigation
- Single-column content
- Full-screen pages
- Compact cards

Medium width:
- NavigationRail
- Two-column content
- Larger cards
- More information visible simultaneously

Large width:
- NavigationRail or NavigationDrawer
- Sidebar + content
- Multi-column dashboard
- Larger data tables
- Master/detail layouts

Do NOT simply scale the phone UI up to tablet size.

The tablet/iPad experience should feel intentionally designed for a larger screen.

---

# 4. DO NOT DETECT "PHONE" OR "TABLET" AS THE MAIN LAYOUT STRATEGY

Do NOT build layouts like:

```dart
if (isTablet) {
   ...
} else {
   ...
}
```

Do NOT depend primarily on:

```dart
Platform.isAndroid
Platform.isIOS
```

Do NOT use physical device model detection for layout decisions.

Instead, base layout decisions primarily on:

```dart
MediaQuery.sizeOf(context)
```

and:

```dart
LayoutBuilder
```

The layout should respond to the **available window width**, not simply the physical device type.

This must also work correctly with:

- Android split-screen
- iPad multitasking
- Foldables
- Resizable windows
- Landscape
- Portrait
- Different aspect ratios

---

# 5. CREATE A CENTRAL RESPONSIVE SYSTEM

Create a reusable responsive/adaptive system instead of scattering breakpoint logic throughout widgets.

For example, create an architecture similar to:

```text
lib/
└── core/
    └── responsive/
        ├── app_breakpoints.dart
        ├── app_responsive.dart
        ├── responsive_builder.dart
        ├── adaptive_layout.dart
        ├── responsive_spacing.dart
        └── responsive_extensions.dart
```

You may change the structure if the existing project architecture suggests a better location.

Do not duplicate responsive logic in every feature.

---

# 6. BREAKPOINT STRATEGY

Create logical breakpoints based on available width.

Start with a system such as:

```text
Compact:
< 600 logical px

Medium:
600 - 839 logical px

Expanded:
840 - 1199 logical px

Large:
>= 1200 logical px
```

However:

DO NOT assume these values are automatically correct for every screen.

Review the actual application UI and adjust breakpoints based on the layout requirements.

The important rule is:

**Breakpoints should represent when the UI needs to change, not what physical device is being used.**

---

# 7. CREATE RESPONSIVE LAYOUT MODES

Create reusable layout modes such as:

```text
CompactLayout
MediumLayout
ExpandedLayout
LargeLayout
```

Or an equivalent architecture that is cleaner for the project.

Each layout should be able to share the same:

- Data
- BLoC
- State
- UseCases
- Repository
- Models
- Business logic

Only the presentation structure should adapt.

---

# 8. NAVIGATION ADAPTATION

Audit the application's navigation.

Use an adaptive navigation strategy.

Example:

### Compact

Use:

```text
NavigationBar
```

or an equivalent compact navigation pattern.

### Medium

Consider:

```text
NavigationRail
```

### Expanded / Large

Consider:

```text
NavigationRail
```

or:

```text
NavigationDrawer
```

depending on the application's information architecture.

Do not duplicate navigation destinations.

Create a shared navigation destination model and render it differently depending on available width.

Example conceptual architecture:

```text
NavigationDestinationData
        │
        ├── Compact → NavigationBar
        │
        ├── Medium → NavigationRail
        │
        └── Expanded → NavigationRail / NavigationDrawer
```

---

# 9. DASHBOARD RESPONSIVENESS

Pay special attention to dashboards.

For phone:

```text
┌───────────────┐
│ Header        │
├───────────────┤
│ Card          │
├───────────────┤
│ Card          │
├───────────────┤
│ Chart         │
├───────────────┤
│ List          │
└───────────────┘
```

For tablet:

```text
┌───────────────┬───────────────┐
│ Card          │ Card          │
├───────────────┼───────────────┤
│ Chart         │ Summary       │
├───────────────┴───────────────┤
│ List                          │
└───────────────────────────────┘
```

For large screens:

```text
┌────────────┬────────────────────────────┐
│ Navigation │ Dashboard                  │
│            │                            │
│            │ ┌──────┐ ┌──────┐ ┌──────┐│
│            │ │ Card │ │ Card │ │ Card ││
│            │ └──────┘ └──────┘ └──────┘│
│            │                            │
│            │ ┌────────────┐ ┌─────────┐ │
│            │ │ Chart      │ │ Summary │ │
│            │ └────────────┘ └─────────┘ │
│            │                            │
│            │ Data / Activity / Tables   │
└────────────┴────────────────────────────┘
```

Do not simply increase the width of mobile cards.

---

# 10. GRID SYSTEM

Do NOT hardcode:

```dart
crossAxisCount: 2
```

for every tablet.

Prefer layouts based on available width.

For example, use:

```dart
SliverGridDelegateWithMaxCrossAxisExtent
```

or an equivalent adaptive grid approach.

The grid should automatically determine the number of columns based on the available width.

Example conceptual behavior:

```text
Phone:
1 column

Small tablet:
2 columns

Large tablet:
3 columns

Large display:
3-5 columns depending on content width
```

The exact number must be determined by available space and item constraints.

---

# 11. CONTENT MAX WIDTH

Do NOT allow text-heavy content to stretch across an extremely wide tablet/iPad display.

Use:

```dart
ConstrainedBox
```

or:

```dart
BoxConstraints
```

with sensible maximum content widths.

For example:

```text
Large screen
┌─────────────────────────────────────────────┐
│                                             │
│        ┌────────────────────────────┐       │
│        │     Main Content           │       │
│        │     Max Width              │       │
│        └────────────────────────────┘       │
│                                             │
└─────────────────────────────────────────────┘
```

Avoid:

```text
████████████████████████████████████████
Full-width text and forms
```

when the content does not need that much space.

---

# 12. RESPONSIVE SPACING

Create centralized spacing tokens.

For example:

```text
Compact:
horizontal padding: 16
small gap: 8
medium gap: 12
large gap: 16

Medium:
horizontal padding: 24
small gap: 12
medium gap: 16
large gap: 24

Expanded:
horizontal padding: 32
small gap: 16
medium gap: 24
large gap: 32
```

Do not blindly use these exact values everywhere.

Evaluate the existing design system and establish consistent tokens.

---

# 13. TYPOGRAPHY

Do NOT scale text aggressively based on screen size.

Typography should remain readable and consistent.

Use:

```dart
Theme.of(context).textTheme
```

and Material 3 typography.

Avoid:

```dart
fontSize: screenWidth * 0.05
```

for normal text.

Avoid making text huge simply because the device is a tablet.

Use typography hierarchy instead:

```text
Display
Headline
Title
Body
Label
```

with sensible constraints.

---

# 14. SAFE AREA

Audit all important screens for:

- Status bar
- Camera cutout
- Dynamic Island
- Home indicator
- Navigation bar
- Rounded corners
- iPad safe areas
- Android edge-to-edge behavior

Use:

```dart
SafeArea
```

where appropriate.

Do not blindly wrap the entire widget tree in SafeArea if it causes incorrect edge-to-edge behavior.

---

# 15. ORIENTATION

Support:

```text
Portrait
Landscape
```

where appropriate.

Do not make the entire application dependent on:

```dart
OrientationBuilder
```

or orientation alone.

Use available width as the main layout signal.

Example:

```text
Portrait phone
→ compact layout

Landscape phone
→ possibly medium layout

Portrait tablet
→ medium/expanded layout

Landscape tablet
→ expanded layout
```

The layout must respond to actual available width.

---

# 16. FORMS

Audit all forms.

Forms should not become excessively wide on tablets.

For large screens:

```text
┌──────────────────────────────────────┐
│                                      │
│       ┌──────────────────────┐       │
│       │ Name                 │       │
│       ├──────────────────────┤       │
│       │ Email                │       │
│       ├──────────────────────┤       │
│       │ Phone                │       │
│       └──────────────────────┘       │
│                                      │
└──────────────────────────────────────┘
```

For appropriate forms, use multi-column layouts on larger screens.

Example:

```text
First Name      Last Name
Email           Phone
Address         Province
```

But maintain logical grouping and accessibility.

---

# 17. LISTS AND DETAIL PAGES

For phone:

```text
List
↓
Tap item
↓
Detail page
```

For tablet:

```text
┌───────────────┬─────────────────────┐
│ List          │ Detail              │
│               │                     │
│ Item 1        │ Selected Item       │
│ Item 2        │                     │
│ Item 3        │ Information         │
└───────────────┴─────────────────────┘
```

When appropriate, implement master/detail adaptive layouts.

Do not force tablet users to repeatedly navigate back and forth when both list and detail can comfortably fit on screen.

---

# 18. TABLES / DATA-HEAVY SCREENS

Audit data tables and business dashboards.

For phones:

- Show only essential columns
- Allow horizontal scrolling where appropriate
- Consider card/list presentation

For tablets:

- Show more columns
- Increase information density carefully

For large screens:

- Use available width efficiently
- Avoid unnecessary horizontal scrolling

Never make a table unreadably compressed just to fit the screen.

---

# 19. DIALOGS AND BOTTOM SHEETS

Dialogs should adapt to available space.

Phone:

```text
BottomSheet / Full-width dialog
```

Tablet:

```text
Centered dialog
with constrained max width
```

Large screen:

```text
Centered dialog
with comfortable max width
```

Do not allow dialogs to become enormous on iPad.

---

# 20. BOTTOM SHEETS

Audit all BottomSheets.

For large screens, consider whether the sheet should instead become:

- Dialog
- Side sheet
- Constrained modal
- Centered modal

depending on the use case.

Do not automatically stretch every BottomSheet across a large tablet screen.

---

# 21. MATERIAL 3

Use Material 3 consistently.

Audit:

- ColorScheme
- Typography
- Cards
- Buttons
- Navigation
- Dialogs
- Bottom sheets
- Text fields
- Chips
- Menus
- Navigation components

Avoid mixing outdated Material 2 patterns with Material 3 without a reason.

Use:

```dart
ThemeData(
  useMaterial3: true,
)
```

where appropriate for the project.

---

# 22. ANDROID VS IOS

Do not create completely different layouts simply because the platform is Android or iOS.

The primary decision should be:

```text
Available window size
+
Platform conventions
+
Input method
```

Use platform-specific behavior only when it genuinely improves the user experience.

Examples:

Android:
- Material conventions
- Android navigation expectations

iOS:
- iOS-specific interaction conventions
- Appropriate Cupertino behavior where needed

Keep the application's visual identity consistent.

---

# 23. INPUT ADAPTATION

Large screens may have:

- Touch
- Stylus
- Mouse
- Trackpad
- Keyboard

Audit interactive components for:

- Minimum touch target
- Hover states
- Focus states
- Keyboard navigation
- Mouse interaction
- Scroll behavior
- Tooltips
- Accessibility semantics

Do not make controls dependent only on touch.

---

# 24. ACCESSIBILITY

Check:

- Text scaling
- Contrast
- Semantic labels
- Touch target size
- Keyboard navigation
- Focus states
- Screen reader compatibility
- Overflow when system font size increases

Do not use fixed heights around text if they can cause clipping when accessibility text scaling increases.

---

# 25. BLoC / CLEAN ARCHITECTURE RULE

This responsive upgrade must NOT violate my architecture.

Keep:

```text
Presentation
    ↓
BLoC / Cubit
    ↓
UseCase
    ↓
Repository
    ↓
DataSource
```

Responsive logic belongs in the presentation layer.

Do NOT put UI breakpoint logic inside:

- Repository
- DataSource
- Entity
- Model
- UseCase
- Business logic

BLoC should manage state/business behavior.

Widgets should decide how that state is presented according to available space.

---

# 26. DO NOT CREATE DUPLICATE BUSINESS LOGIC

If the same data appears in:

```text
Phone UI
Tablet UI
iPad UI
```

all layouts must consume the same state.

Example:

```text
                   BLoC
                    │
              State / Data
                    │
        ┌───────────┼───────────┐
        ↓           ↓           ↓
     Compact     Medium      Expanded
       UI          UI           UI
```

Do not create:

```text
PhoneBloc
TabletBloc
iPadBloc
```

unless there is a genuine business requirement.

---

# 27. COMPONENT ARCHITECTURE

Identify reusable UI components.

Examples:

```text
ResponsiveScaffold
AdaptiveNavigation
ResponsiveContainer
ResponsiveGrid
ResponsiveCard
AdaptiveDialog
AdaptiveBottomSheet
ResponsiveForm
ResponsiveListDetail
ResponsiveDashboard
```

Only create components where they actually improve maintainability.

Do not create unnecessary abstraction.

---

# 28. RESPONSIVE EXTENSIONS

If useful, create clean helpers such as:

```dart
context.isCompact
context.isMedium
context.isExpanded
context.isLarge
```

or:

```dart
context.responsive
```

But keep them strongly typed and simple.

Do not hide complicated logic behind extensions.

---

# 29. PERFORMANCE

The responsive system must not create unnecessary rebuilds.

Pay attention to:

- BLoC rebuilds
- BlocBuilder buildWhen
- const widgets
- ListView
- GridView
- Slivers
- LayoutBuilder
- MediaQuery
- image loading
- expensive layouts

Use:

```dart
const
```

where appropriate.

Keep widgets small and focused.

Do not rebuild an entire page when only a small component needs to change.

---

# 30. TESTING MATRIX

After implementation, test at minimum:

### Android phone

```text
Small phone portrait
Medium phone portrait
Large phone portrait
Large phone landscape
```

### iPhone

```text
Small iPhone
Standard iPhone
Large iPhone
Dynamic Island / Safe Area
Portrait
Landscape
```

### Android tablet

```text
Small tablet portrait
Small tablet landscape
Large tablet portrait
Large tablet landscape
Split-screen
```

### iPad

```text
iPad portrait
iPad landscape
iPad multitasking / resized window
```

Also test unusual widths.

Do NOT test only one phone and one tablet.

---

# 31. GOLDEN / WIDGET TESTING

Where practical, create responsive widget tests for important screens.

Test widths such as:

```text
360
390
430
600
768
834
1024
1200
1440
```

Test:

- Layout changes
- Overflow
- Navigation changes
- Grid column changes
- Text clipping
- Dialog sizing
- Form layouts
- Dashboard layouts

Use Flutter widget tests and golden tests where they provide meaningful value.

---

# 32. OVERFLOW DETECTION

Search for and fix:

```text
RenderFlex overflowed
A RenderFlex overflowed by ...
Horizontal viewport was given unbounded width
Vertical viewport was given unbounded height
Bottom overflow
Text overflow
```

Do not simply solve overflow by adding random:

```dart
SingleChildScrollView
```

Understand the underlying layout problem first.

---

# 33. RESPONSIVE DESIGN QUALITY RULES

The final application should satisfy:

### Phone

- Comfortable one-handed interaction
- No horizontal overflow
- Clear hierarchy
- Compact navigation
- Appropriate spacing
- Easy scrolling

### Tablet

- Better information density
- Two-column layouts where appropriate
- NavigationRail/side navigation where appropriate
- More content visible simultaneously
- Avoid giant stretched cards

### iPad

- Professional large-screen experience
- Proper content constraints
- Good use of horizontal space
- Master/detail layouts where appropriate
- Appropriate navigation
- Excellent portrait and landscape behavior

---

# 34. DO NOT OVERENGINEER

Do not introduce:

- unnecessary packages
- unnecessary dependencies
- duplicate layout systems
- duplicate BLoCs
- giant responsive widgets
- excessive abstractions
- device-specific hacks
- hardcoded device model detection

Prefer Flutter's built-in APIs where possible.

---

# 35. IMPLEMENTATION PROCESS

Follow this process exactly.

## Phase 1 — Audit

Inspect the project.

Report:

```text
Flutter version:
Dart version:
Architecture:
State management:
Theme:
Responsive packages:
Navigation:
Main UI problems:
Current breakpoints:
Potential overflow areas:
```

Do not modify anything yet.

## Phase 2 — Responsive Architecture Proposal

Create a proposal containing:

```text
Breakpoint system
Responsive utility structure
Navigation strategy
Dashboard strategy
Grid strategy
Form strategy
Dialog strategy
Tablet strategy
iPad strategy
Orientation strategy
Testing strategy
```

## Phase 3 — Implementation

Implement the responsive foundation.

Then migrate screens incrementally.

Prioritize:

1. App shell
2. Navigation
3. Dashboard
4. Main lists
5. Detail screens
6. Forms
7. Tables
8. Dialogs
9. Bottom sheets
10. Secondary screens

## Phase 4 — Validation

Run:

```bash
flutter analyze
flutter test
```

and any project-specific:

```bash
flutter build apk
flutter build ios
```

commands that are appropriate and available in the environment.

Do not run destructive commands.

---

# 36. BEFORE/AFTER REPORT

At the end, provide a report:

```text
RESPONSIVE UPGRADE REPORT

Architecture:
- ...

Breakpoints:
- ...

Navigation:
- ...

Phone:
- ...

Tablet:
- ...

iPad:
- ...

Landscape:
- ...

Safe Area:
- ...

Accessibility:
- ...

Performance:
- ...

Tests:
- ...

Files created:
- ...

Files modified:
- ...

Packages added:
- ...

Packages removed:
- ...

Remaining issues:
- ...
```

Also identify any screens that still need manual visual review.

---

# 37. FINAL QUALITY STANDARD

The final result should feel like a professionally designed modern Flutter application, not:

```text
Mobile UI + stretched tablet UI
```

Instead it should feel like:

```text
                 ONE APPLICATION
                       │
          ┌────────────┼────────────┐
          ↓            ↓            ↓
       Compact       Medium      Expanded
          │            │            │
       Phone        Tablet       Tablet/iPad
          │            │            │
          └────────────┼────────────┘
                       ↓
                Shared BLoC/Data
```

The application must:

- Look professional
- Feel natural on phones
- Feel intentionally designed on tablets
- Work well on iPad
- Support portrait and landscape appropriately
- Handle window resizing
- Avoid overflow
- Avoid excessive empty space
- Avoid excessively wide content
- Maintain consistent branding
- Maintain Clean Architecture
- Maintain BLoC architecture
- Remain easy to maintain
- Remain scalable for future Flutter versions and devices

IMPORTANT:

Do not blindly refactor the entire application.

Inspect first.
Plan second.
Implement third.
Test fourth.
Report fifth.

Start with **Phase 1 — Audit the existing project**.