# Dark Theme Adaptation Design

**Date:** 2026-07-21  
**Status:** Approved for planning

## Goal

Adapt Lecture Notes for system Dark Appearance so every UI element remains readable and on-brand—not only a dark background. Appearance follows the iOS system setting only (no in-app theme picker).

## Decisions

| Decision | Choice |
|---|---|
| Theme control | System only — remove `.preferredColorScheme(.light)` |
| Visual language | Semantic inversion of the current black/white “ink on paper” look |
| Scope | Full app **except paywall** (paywall configured separately) |
| Approach | Central semantic color tokens (`AppColor` / asset colors) |

## Out of scope

- Entire `Modules/Paywall/` surface (including import-limit / upsell sheets configured with paywall)
- In-app Light / Dark / System picker in Settings
- Redesigning layout, typography, or feature behavior
- Changing splash branding (remains black branded splash)

## Architecture: semantic tokens

Introduce a small adaptive palette used across SwiftUI (and UIKit where needed):

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `systemGray6` (adaptive) | same system adaptive | Screen backgrounds |
| `surface` | white | `systemBackground` / elevated card surface (not pure black canvas) | Cards, fields, sheet content panels |
| `fillSubtle` | black ~5% | white ~8–10% | Soft icon button fills, unselected chip fills |
| `ink` | black / label-equivalent | white / label-equivalent | Primary CTA fills, selected chips, solid progress |
| `onInk` | white | black | Label/icon on `ink` |
| `hairline` | black ~5% | white ~10% | Thin borders / strokes |
| `overlayScrim` | black ~14–18% | black ~40–50% | Dim behind overlays |
| `shadow` | black low opacity | softer / lower opacity | Card shadows |

**Implementation preference:** `Color` extension (`AppColor`) and, where convenient, Asset Catalog colors with Any Appearance / Dark variants. UIKit borders (e.g. text import) use dynamic `UIColor` mapped to the same tokens.

Do **not** sprinkle ad-hoc `@Environment(\.colorScheme)` branches per view unless a one-off truly cannot be expressed as a token.

## Replacement patterns

| Current pattern | Replacement |
|---|---|
| `.background(.white)` / card `Color.white` | `AppColor.surface` |
| `.background(.black)` / selected chip black | `AppColor.ink` + `AppColor.onInk` for foreground |
| `.black.opacity(0.05)` soft fills | `AppColor.fillSubtle` |
| `black.opacity(0.03–0.10)` strokes | `AppColor.hairline` (or opacity variants of that token) |
| Modal dim overlays | `AppColor.overlayScrim` |
| `.tint(.black)` / `.tint(.white)` on primary actions | `ink` / `onInk` |
| Quiz success/error RGB hues | Keep hue; verify contrast on dark; nudge if needed |

Semantic SwiftUI colors already in use (`.primary`, `.secondary`, `Color(.systemGray6)` where appropriate) may remain when they already map correctly; prefer tokens when the intent is brand ink/surface rather than system chrome.

## Work order

1. **Foundation** — add `AppColor` (+ UIKit helpers if needed).
2. **Unlock** — remove `.preferredColorScheme(.light)` in `lecturenotesApp.swift`.
3. **Shared chrome** — chips, floating record button, headers, soft icon buttons, shared sheet backgrounds.
4. **Core flows** — lectures list / folders, lecture detail + audio player, recorder / mini recorder.
5. **Study** — quiz, flashcards, processing.
6. **Settings, onboarding, import sheets** (YouTube / text) — skip paywall.
7. **QA pass** — light and dark on the screens above; fix contrast and muddy shadows.

## Success criteria

- With system Dark Appearance: no leftover light-only white panels, no black CTAs on dark canvas without inversion, no unreadable text/icons.
- With system Light Appearance: visual language remains equivalent to today.
- Paywall unchanged by this work.
- Splash remains the black branded screen.
- Switching system Appearance updates the app without relaunch (standard SwiftUI environment behavior).

## Testing checklist

- [ ] Home / lectures list + folder chips + floating record
- [ ] Folders screen / folder sheets
- [ ] Lecture detail + audio player + tab chrome
- [ ] Recorder / mini recorder sheet
- [ ] Quiz + quiz results
- [ ] Flashcards practice
- [ ] Processing
- [ ] Settings
- [ ] Onboarding
- [ ] YouTube import + text import sheets
- [ ] Confirm paywall still as configured separately
- [ ] Confirm splash unchanged
