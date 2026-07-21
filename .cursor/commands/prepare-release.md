---
description: Bump build, archive Release, open Xcode Organizer for App Store upload
---

# Prepare Release Archive

Run the solo App Store release prep for Doable Habits.

## Steps

1. From the repo root, run one of:

```bash
./scripts/prepare-release.sh
```

Or, only if the user asked for a new marketing version:

```bash
./scripts/prepare-release.sh 1.6
```

2. Wait for the archive to finish. The script will:
   - Sync `MARKETING_VERSION` on app + widgets (optional override from the argument)
   - Increment `CURRENT_PROJECT_VERSION` on all targets
   - Build a Release `.xcarchive` into `~/Library/Developer/Xcode/Archives/`
   - Open Xcode Organizer on that archive

3. Report back to the user:
   - Final **Version (Build)**
   - Path to the `.xcarchive`
   - That `project.pbxproj` was modified by the bump (do **not** commit unless asked)
   - Next manual step: Organizer → **Distribute App** → App Store Connect

## Rules

- Do not invent a new marketing version unless the user explicitly asked for one (e.g. `/prepare-release 1.6`).
- Do not upload to App Store Connect; stop after Organizer is open.
- Do not create a git commit unless the user asks.
- If the script fails (signing, build error), show the relevant `xcodebuild` error and stop; do not partially “fix” versions by hand unless asked.
