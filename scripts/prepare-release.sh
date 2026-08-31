#!/usr/bin/env bash
# Prepare a Release archive for App Store upload:
# 1) Sync MARKETING_VERSION across app + widgets (optional override)
# 2) Increment CURRENT_PROJECT_VERSION on all targets
# 3) xcodebuild archive
# 4) Open Xcode Organizer on the new archive
#
# Usage:
#   ./scripts/prepare-release.sh
#   ./scripts/prepare-release.sh 2.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="lecturenotes.xcodeproj"
SCHEME="lecturenotes"
PBX="$PROJECT/project.pbxproj"
OPTIONAL_MARKETING_VERSION="${1:-}"

if [[ ! -f "$PBX" ]]; then
  echo "error: missing $PBX" >&2
  exit 1
fi

if [[ -n "$OPTIONAL_MARKETING_VERSION" && ! "$OPTIONAL_MARKETING_VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "error: marketing version must look like 1.5 or 1.5.1 (got: $OPTIONAL_MARKETING_VERSION)" >&2
  exit 1
fi

VERSION_LINE="$(
  python3 - "$PBX" "$OPTIONAL_MARKETING_VERSION" <<'PY'
import re
import sys
from pathlib import Path

pbx = Path(sys.argv[1])
optional_marketing = sys.argv[2].strip() if len(sys.argv) > 2 else ""
text = pbx.read_text()

builds = [int(m) for m in re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", text)]
marketings = re.findall(r"MARKETING_VERSION = ([^;]+);", text)

if not builds:
    sys.exit("error: no CURRENT_PROJECT_VERSION found in project.pbxproj")
if not marketings:
    sys.exit("error: no MARKETING_VERSION found in project.pbxproj")

# App configs appear before widgets in this project — use the first as canonical
# unless the user passed an explicit marketing version.
canonical_marketing = optional_marketing or marketings[0].strip()
new_build = max(builds) + 1

updated = re.sub(
    r"CURRENT_PROJECT_VERSION = \d+;",
    f"CURRENT_PROJECT_VERSION = {new_build};",
    text,
)
updated = re.sub(
    r"MARKETING_VERSION = [^;]+;",
    f"MARKETING_VERSION = {canonical_marketing};",
    updated,
)
pbx.write_text(updated)
print(f"{canonical_marketing}|{new_build}")
PY
)"

MARKETING_VERSION="${VERSION_LINE%%|*}"
BUILD_NUMBER="${VERSION_LINE##*|}"

echo "→ Version ${MARKETING_VERSION} (${BUILD_NUMBER})"

ARCHIVE_DAY="$(date +%Y-%m-%d)"
ARCHIVE_DIR="${HOME}/Library/Developer/Xcode/Archives/${ARCHIVE_DAY}"
mkdir -p "$ARCHIVE_DIR"
ARCHIVE_PATH="${ARCHIVE_DIR}/Lectra ${ARCHIVE_DAY} ${BUILD_NUMBER}.xcarchive"

echo "→ Archiving ${SCHEME} (Release) → ${ARCHIVE_PATH}"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_STYLE=Automatic

echo "→ Opening Organizer"
open -a Xcode "$ARCHIVE_PATH" || true
osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "Xcode" to activate
delay 0.8
tell application "System Events"
  tell process "Xcode"
    set frontmost to true
    try
      click menu item "Organizer" of menu "Window" of menu bar 1
    end try
  end tell
end tell
APPLESCRIPT

echo
echo "Ready: ${MARKETING_VERSION} (${BUILD_NUMBER})"
echo "Archive: ${ARCHIVE_PATH}"
echo "Next: Organizer → Distribute App → App Store Connect"
echo "Note: project.pbxproj was modified (version bump). Commit only if you want."
