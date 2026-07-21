# Dark Theme Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Lecture Notes correctly follow system Light/Dark Appearance via semantic `AppColor` tokens, without changing paywall or splash branding.

**Architecture:** Add a small adaptive `AppColor` / `AppUIColor` palette, remove the forced `.preferredColorScheme(.light)`, then replace hardcoded `.black` / `.white` / `black.opacity` UI fills across non-paywall screens with those tokens so ink/surface invert correctly in Dark Mode.

**Tech Stack:** SwiftUI, UIKit (dynamic `UIColor` for text-import border), iOS 26+, Xcode synchronized file groups (new files under `lecturenotes/` are picked up automatically).

## Global Constraints

- Follow system Appearance only — no Settings theme picker.
- Do not modify anything under `lecturenotes/Modules/Paywall/`.
- Do not change `SplashScreenView` branding (keep black background + white content).
- Prefer `AppColor` tokens over per-view `@Environment(\.colorScheme)` branches.
- No third-party frameworks.
- No unit-test target in this repo — verify with `xcodebuild` build + manual Appearance QA checklist from the spec.
- Commits only when the user asks, unless a task step says to commit and the user already approved plan execution that includes commits; when committing, follow repo commit style.

**Spec:** `docs/superpowers/specs/2026-07-21-dark-theme-adaptation-design.md`

---

## File map

| File | Responsibility |
|---|---|
| Create: `lecturenotes/Common/Theme/AppColor.swift` | SwiftUI semantic tokens |
| Create: `lecturenotes/Common/Theme/AppUIColor.swift` | UIKit dynamic colors matching tokens |
| Modify: `lecturenotes/lecturenotesApp.swift` | Remove light lock |
| Modify: shared chrome + core/study/settings/onboarding/import views listed per task | Apply tokens |
| Skip: `lecturenotes/Modules/Paywall/**`, `lecturenotes/App/SplashScreenView.swift` | Out of scope |

---

### Task 1: AppColor + AppUIColor foundation

**Files:**
- Create: `lecturenotes/Common/Theme/AppColor.swift`
- Create: `lecturenotes/Common/Theme/AppUIColor.swift`

**Interfaces:**
- Consumes: none
- Produces:
  - `enum AppColor` with static `Color` properties: `canvas`, `surface`, `fillSubtle`, `ink`, `onInk`, `hairline`, `overlayScrim`, `shadow`
  - `enum AppUIColor` with static `UIColor` properties: `hairline` (and any other UIKit-needed token used later — at minimum `hairline`)

- [ ] **Step 1: Create `AppUIColor.swift`**

```swift
import UIKit

enum AppUIColor {
    static let hairline = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.05)
    }

    static let fillSubtle = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.05)
    }

    static let ink = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    }

    static let onInk = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    }

    static let surface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .secondarySystemBackground
            : .white
    }

    static let overlayScrim = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.16)
    }

    static let shadow = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.12)
    }
}
```

- [ ] **Step 2: Create `AppColor.swift`**

```swift
import SwiftUI

enum AppColor {
    static let canvas = Color(.systemGray6)
    static let surface = Color(uiColor: AppUIColor.surface)
    static let fillSubtle = Color(uiColor: AppUIColor.fillSubtle)
    static let ink = Color(uiColor: AppUIColor.ink)
    static let onInk = Color(uiColor: AppUIColor.onInk)
    static let hairline = Color(uiColor: AppUIColor.hairline)
    static let overlayScrim = Color(uiColor: AppUIColor.overlayScrim)
    static let shadow = Color(uiColor: AppUIColor.shadow)
}
```

- [ ] **Step 3: Build to verify new files compile**

Run:

```bash
xcodebuild -scheme lecturenotes -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `BUILD SUCCEEDED` (simulator name may differ; use an available iPhone simulator from `xcrun simctl list devices available`).

- [ ] **Step 4: Commit** (if execution mode includes commits)

```bash
git add lecturenotes/Common/Theme/AppColor.swift lecturenotes/Common/Theme/AppUIColor.swift
git commit -m "Add AppColor semantic palette for dark mode."
```

---

### Task 2: Unlock system Appearance

**Files:**
- Modify: `lecturenotes/lecturenotesApp.swift` (remove `.preferredColorScheme(.light)`)

**Interfaces:**
- Consumes: none
- Produces: app follows system `colorScheme`

- [ ] **Step 1: Remove the light lock**

In `lecturenotes/lecturenotesApp.swift`, delete this modifier from the root content:

```swift
.preferredColorScheme(.light)
```

Leave neighboring modifiers (`.environmentObject`, `.environment`, `.locale`, etc.) unchanged.

- [ ] **Step 2: Build**

Same `xcodebuild` command as Task 1. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit** (if enabled)

```bash
git add lecturenotes/lecturenotesApp.swift
git commit -m "Follow system color scheme instead of forcing light."
```

---

### Task 3: Shared chrome (chips, FAB, soft fills, headers)

**Files:**
- Modify: `lecturenotes/Modules/LecturesList/FolderFilterChipsView.swift`
- Modify: `lecturenotes/Modules/LecturesList/FloatingRecordButton.swift`
- Modify: `lecturenotes/Modules/LecturesList/HomeHeaderView.swift`
- Modify: `lecturenotes/Modules/LecturesList/QuickActionButtonView.swift`
- Modify: `lecturenotes/Modules/LecturesList/FolderListContentView.swift` (soft icon fills only; ignore whitespace trim lines)

**Interfaces:**
- Consumes: `AppColor.ink`, `AppColor.onInk`, `AppColor.surface`, `AppColor.fillSubtle`
- Produces: adaptive chips / FAB / soft buttons

- [ ] **Step 1: Update `FolderFilterChipsView` chip colors**

Replace:

```swift
.foregroundStyle(isSelected ? .white : .primary)
...
.background(isSelected ? .black : .white)
```

with:

```swift
.foregroundStyle(isSelected ? AppColor.onInk : .primary)
...
.background(isSelected ? AppColor.ink : AppColor.surface)
```

- [ ] **Step 2: Update `FloatingRecordButton`**

Replace:

```swift
.foregroundStyle(.white)
.frame(width: 72, height: 72)
.background(.black)
```

with:

```swift
.foregroundStyle(AppColor.onInk)
.frame(width: 72, height: 72)
.background(AppColor.ink)
```

Keep existing `.shadow(radius: 8)` unless it looks muddy in dark during QA (then use `.shadow(color: AppColor.shadow, radius: 8)`).

- [ ] **Step 3: Replace soft fills in header / quick actions / folder list**

In `HomeHeaderView`, `QuickActionButtonView`, and `FolderListContentView`, replace every:

```swift
.background(.black.opacity(0.05))
```

with:

```swift
.background(AppColor.fillSubtle)
```

- [ ] **Step 4: Build**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit** (if enabled)

```bash
git add lecturenotes/Modules/LecturesList/FolderFilterChipsView.swift \
  lecturenotes/Modules/LecturesList/FloatingRecordButton.swift \
  lecturenotes/Modules/LecturesList/HomeHeaderView.swift \
  lecturenotes/Modules/LecturesList/QuickActionButtonView.swift \
  lecturenotes/Modules/LecturesList/FolderListContentView.swift
git commit -m "Adapt shared list chrome for dark mode."
```

---

### Task 4: Lectures list + consent card overlays

**Files:**
- Modify: `lecturenotes/Modules/LecturesList/LecturesListView.swift`
- Modify: `lecturenotes/Modules/LecturesList/AIProcessingConsentCard.swift`
- Do **not** change `PremiumBannerView.swift` white-on-gradient styling (already dark-gradient content; leave as-is)

**Interfaces:**
- Consumes: `AppColor` tokens from Task 1
- Produces: adaptive list overlays, toast/CTA bars, inline chips, consent card

- [ ] **Step 1: Replace list overlays / chips / toast in `LecturesListView`**

Apply these mappings wherever they appear in this file (skip `trimmingCharacters` lines):

| Current | Replacement |
|---|---|
| `Color.black.opacity(0.18)` / `Color.black.opacity(0.14)` scrims | `AppColor.overlayScrim` |
| `.foregroundStyle(.white)` on solid ink bars | `AppColor.onInk` |
| `.background(.black.opacity(0.88))` bars | `AppColor.ink.opacity(0.88)` |
| `.background(.black.opacity(0.05))` | `AppColor.fillSubtle` |
| selected chip `.foregroundStyle(isSelected ? .white : .primary)` | `isSelected ? AppColor.onInk : .primary` |
| selected chip `.background(isSelected ? .black : .white)` | `isSelected ? AppColor.ink : AppColor.surface` |
| `Color(.systemGray6)` screen bg (optional) | `AppColor.canvas` for consistency |

- [ ] **Step 2: Update `AIProcessingConsentCard`**

Replace:

```swift
background: Color.black.opacity(0.06),
```

with:

```swift
background: AppColor.fillSubtle,
```

Replace stroke/shadow:

```swift
.stroke(.black.opacity(0.04), lineWidth: 1)
...
.shadow(color: .black.opacity(0.08), radius: 24, y: 12)
```

with:

```swift
.stroke(AppColor.hairline, lineWidth: 1)
...
.shadow(color: AppColor.shadow, radius: 24, y: 12)
```

Replace destructive/secondary label logic only where white is used as on-ink:

```swift
.foregroundStyle(usesPrimaryForeground ? Color.primary : AppColor.onInk)
```

Replace card surface fill `Color(.systemBackground)` only if it should track `AppColor.surface`; prefer `AppColor.surface` for the card fill.

Keep the red destructive button RGB as-is.

Replace:

```swift
Color.black.opacity(0.1)
```

shadow helper (if present) with `AppColor.shadow` or `AppColor.hairline` depending on use (shadow → `AppColor.shadow`).

- [ ] **Step 3: Build**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit** (if enabled)

```bash
git add lecturenotes/Modules/LecturesList/LecturesListView.swift \
  lecturenotes/Modules/LecturesList/AIProcessingConsentCard.swift
git commit -m "Adapt lectures list and consent card for dark mode."
```

---

### Task 5: Lecture detail + audio player

**Files:**
- Modify: `lecturenotes/Modules/LectureDetail/LectureDetailView.swift`
- Modify: `lecturenotes/Modules/LectureDetail/LectureAudioPlayerView.swift`

**Interfaces:**
- Consumes: `AppColor`
- Produces: adaptive detail chrome and player scrubber

- [ ] **Step 1: Update `LectureDetailView`**

Replace soft fills / strokes / shadows / ink bars:

| Current | Replacement |
|---|---|
| `Color(.systemGray6)` bg | `AppColor.canvas` |
| `.background(.black.opacity(0.05))` | `AppColor.fillSubtle` |
| `Color.black.opacity(0.10)` / `0.03` strokes | `AppColor.hairline` (selected can use `AppColor.hairline`; unselected `AppColor.hairline.opacity(0.6)` if needed) |
| `.shadow(color: .black.opacity(...))` | `AppColor.shadow` (keep radius/y) |
| toast `.foregroundStyle(.white)` + `.background(.black.opacity(0.88))` | `AppColor.onInk` + `AppColor.ink.opacity(0.88)` |

Do not touch whitespace-trim disable logic.

- [ ] **Step 2: Update `LectureAudioPlayerView`**

Replace:

```swift
.background(Color.black.opacity(0.08))
.fill(.black.opacity(0.08))
.fill(.black)
.shadow(color: .black.opacity(0.12), ...)
```

with:

```swift
.background(AppColor.fillSubtle)
.fill(AppColor.fillSubtle)
.fill(AppColor.ink)
.shadow(color: AppColor.shadow, ...)
```

- [ ] **Step 3: Build + Commit** (if enabled)

```bash
git add lecturenotes/Modules/LectureDetail/LectureDetailView.swift \
  lecturenotes/Modules/LectureDetail/LectureAudioPlayerView.swift
git commit -m "Adapt lecture detail and audio player for dark mode."
```

---

### Task 6: Recorder

**Files:**
- Modify: `lecturenotes/Modules/Recorder/MiniRecorderSheetView.swift`
- Check `lecturenotes/Modules/Recorder/RecorderView.swift` — only `.secondary` today; no change unless hardcoded black/white appears

**Interfaces:**
- Consumes: `AppColor.shadow`, `AppColor.onInk`
- Produces: adaptive mini recorder sheet

- [ ] **Step 1: Update shadows in `MiniRecorderSheetView`**

Replace `.shadow(color: .black.opacity(...), ...)` with `.shadow(color: AppColor.shadow, ...)` (keep radius/y).

Keep the red stop button `Color(red: 0.88, green: 0.33, blue: 0.33)` and its `.foregroundStyle(.white)` — white on red is intentional and readable in both modes.

- [ ] **Step 2: Build + Commit** (if enabled)

```bash
git add lecturenotes/Modules/Recorder/MiniRecorderSheetView.swift
git commit -m "Adapt mini recorder sheet shadows for dark mode."
```

---

### Task 7: Quiz + flashcards + processing

**Files:**
- Modify: `lecturenotes/Modules/Quiz/QuizView.swift`
- Modify: `lecturenotes/Modules/Quiz/QuizOptionButton.swift`
- Modify: `lecturenotes/Modules/Quiz/QuizResultView.swift`
- Modify: `lecturenotes/Modules/FlashcardsPractice/FlashcardsPracticeView.swift`
- Modify: `lecturenotes/Modules/Processing/ProcessingView.swift`

**Interfaces:**
- Consumes: `AppColor`
- Produces: adaptive study/processing UI; keep quiz success/error hues

- [ ] **Step 1: `QuizView`**

| Current | Replacement |
|---|---|
| `Color(.systemGray6)` | `AppColor.canvas` |
| `.fill(.black.opacity(0.06))` | `AppColor.fillSubtle` |
| `.fill(.black.opacity(0.85))` progress/ink | `AppColor.ink.opacity(0.85)` |
| `.background(Color.black.opacity(0.03))` | `AppColor.fillSubtle` or `AppColor.hairline` (use fillSubtle for soft panel) |
| `.background(.white)` card | `AppColor.surface` |
| `.shadow(color: .black.opacity(0.06), ...)` | `AppColor.shadow` |

- [ ] **Step 2: `QuizOptionButton`**

Idle background `.white` → `AppColor.surface`.  
Idle border `.black.opacity(0.10)` → `AppColor.hairline`.  
Keep success/error `Color(red:...)` values; only swap neutral white/black.

- [ ] **Step 3: `QuizResultView`**

Card `.background(.white)` → `AppColor.surface`.  
Stroke `.black.opacity(0.10)` → `AppColor.hairline`.  
Keep the dark gradient header (`Color.black` → charcoal) and `.foregroundStyle(.white)` on that gradient — it is intentionally dark in both modes.

- [ ] **Step 4: `FlashcardsPracticeView`**

| Current | Replacement |
|---|---|
| `Color(.systemGray6)` | `AppColor.canvas` |
| `.background(.white)` | `AppColor.surface` |
| `.shadow(color: .black.opacity(0.06), ...)` | `AppColor.shadow` |
| page dots `.black` / `.black.opacity(0.12)` | `AppColor.ink` / `AppColor.fillSubtle` |

- [ ] **Step 5: `ProcessingView`**

| Current | Replacement |
|---|---|
| primary CTA `.fill(.black)` + white label/tint | `AppColor.ink` + `AppColor.onInk` |
| `.tint(.black)` on secondary controls | `AppColor.ink` |
| progress track `.black.opacity(0.08)` / fill `.black` | `AppColor.fillSubtle` / `AppColor.ink` |
| `Color(.systemGray6)` | `AppColor.canvas` |
| Keep red error hues | unchanged |

- [ ] **Step 6: Build + Commit** (if enabled)

```bash
git add lecturenotes/Modules/Quiz/QuizView.swift \
  lecturenotes/Modules/Quiz/QuizOptionButton.swift \
  lecturenotes/Modules/Quiz/QuizResultView.swift \
  lecturenotes/Modules/FlashcardsPractice/FlashcardsPracticeView.swift \
  lecturenotes/Modules/Processing/ProcessingView.swift
git commit -m "Adapt quiz, flashcards, and processing for dark mode."
```

---

### Task 8: Settings, onboarding, import sheets

**Files:**
- Modify: `lecturenotes/Modules/Settings/SettingsView.swift`
- Modify: `lecturenotes/Modules/Onboarding/OnboardingView.swift`
- Modify: `lecturenotes/Modules/YouTubeImport/YouTubeImportSheetView.swift`
- Modify: `lecturenotes/Modules/TextImport/TextImportSheetView.swift`
- Skip: all `lecturenotes/Modules/Paywall/**`

**Interfaces:**
- Consumes: `AppColor`, `AppUIColor.hairline`
- Produces: adaptive settings/onboarding/import UI

- [ ] **Step 1: `SettingsView`**

Replace every `.background(.black.opacity(0.05))` with `AppColor.fillSubtle`.  
Optionally map `Color(.systemGray6)` → `AppColor.canvas`.

- [ ] **Step 2: `OnboardingView`**

| Current | Replacement |
|---|---|
| `Color(.systemGray6)` | `AppColor.canvas` |
| strokes `.black.opacity(0.04)` | `AppColor.hairline` |
| shadows `.black.opacity(0.04)` | `AppColor.shadow` |
| fills `.black.opacity(0.06)` | `AppColor.fillSubtle` |
| primary CTA white label on black fill | `AppColor.onInk` on `AppColor.ink` |

- [ ] **Step 3: `YouTubeImportSheetView`**

| Current | Replacement |
|---|---|
| field `.background(.white)` | `AppColor.surface` |
| stroke `.black.opacity(0.05)` | `AppColor.hairline` |
| loading `.tint(.white)` on ink button | `AppColor.onInk` |
| `.tint(.black)` primary | `AppColor.ink` |
| `Color(.systemGray6)` | `AppColor.canvas` |

- [ ] **Step 4: `TextImportSheetView`**

SwiftUI tints: same as YouTube (`AppColor.ink` / `AppColor.onInk`).  
UIKit border in `makeUIView`:

```swift
textView.layer.borderColor = AppUIColor.hairline.cgColor
```

Note: `cgColor` from dynamic `UIColor` is resolved at call time. Also update border in `updateUIView` (or trait change handler if present) so rotation/Appearance changes refresh:

```swift
textView.layer.borderColor = AppUIColor.hairline.resolvedColor(with: textView.traitCollection).cgColor
```

Call that in `updateUIView` every time.

- [ ] **Step 5: Build + Commit** (if enabled)

```bash
git add lecturenotes/Modules/Settings/SettingsView.swift \
  lecturenotes/Modules/Onboarding/OnboardingView.swift \
  lecturenotes/Modules/YouTubeImport/YouTubeImportSheetView.swift \
  lecturenotes/Modules/TextImport/TextImportSheetView.swift
git commit -m "Adapt settings, onboarding, and import sheets for dark mode."
```

---

### Task 9: Final sweep + QA

**Files:**
- Re-scan non-paywall SwiftUI for leftover hardcoded light-only patterns
- No intentional changes to Splash or Paywall

- [ ] **Step 1: Grep for leftovers**

Run:

```bash
rg -n "\.background\(\.white\)|\.background\(\.black\)|Color\.black\.opacity|\.black\.opacity|preferredColorScheme|\.tint\(\.black\)|\.tint\(\.white\)" \
  lecturenotes --glob '*.swift' -g '!**/Paywall/**' -g '!**/SplashScreenView.swift'
```

Expected leftovers only where intentional:
- Splash (excluded by glob)
- White on red stop button / white on dark quiz result gradient / premium banner white-on-gradient
- Any remaining should be converted to `AppColor` or justified in the commit message

- [ ] **Step 2: Build Release/Debug once more**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Manual Appearance checklist** (Simulator: Features → Appearance → Dark / Light)

- [ ] Home / chips / FAB
- [ ] Folders
- [ ] Lecture detail + audio player
- [ ] Mini recorder
- [ ] Quiz + results
- [ ] Flashcards
- [ ] Processing
- [ ] Settings
- [ ] Onboarding
- [ ] YouTube + text import
- [ ] Paywall unchanged
- [ ] Splash unchanged

- [ ] **Step 4: Fix any muddy shadows / low-contrast hits found in QA**, rebuild, then final commit if enabled:

```bash
git commit -m "Polish dark mode contrast after Appearance QA."
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|---|---|
| System Appearance only | Task 2 |
| Semantic ink/surface tokens | Task 1 |
| Full app except paywall | Tasks 3–8; Task 9 grep excludes Paywall |
| Splash unchanged | Explicit skip |
| Replacement patterns | Tasks 3–8 tables |
| Work order foundation→QA | Tasks 1→9 |
| Success criteria / checklist | Task 9 |

No TBD placeholders. Token names consistent: `AppColor.*` / `AppUIColor.*`.
