#!/usr/bin/env bash
# Captures main-window layout verification shots (Mac Care / Work Rhythm / Settings page).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/scripts/output/layout-audit"
APP="$(
  find "$HOME/Library/Developer/Xcode/DerivedData"/JoeyPet-*/Build/Products/Debug/JoeyPet.app -maxdepth 0 2>/dev/null | head -1
)"
if [[ -z "$APP" ]]; then
  echo "Build JoeyPet Debug first (xcodebuild -project JoeyPet.xcodeproj -scheme JoeyPet build)." >&2
  exit 1
fi
mkdir -p "$OUT"
pkill -x JoeyPet 2>/dev/null || true
sleep 0.5

capture_window() {
  local label="$1"
  shift
  open -a "$APP" --args "$@"
  sleep 2.5
  osascript -e 'tell application "JoeyPet" to activate' >/dev/null 2>&1 || true
  sleep 0.4
  local wid
  wid="$(osascript -e 'tell application "System Events" to tell process "JoeyPet" to get id of window 1' 2>/dev/null || true)"
  if [[ -n "$wid" && "$wid" != "missing value" ]]; then
    screencapture -x -l"$wid" "$OUT/$label.png"
    echo "Wrote $OUT/$label.png"
  else
    echo "Could not get JoeyPet window id for $label; grant Accessibility to Terminal/Cursor." >&2
    exit 1
  fi
  pkill -x JoeyPet 2>/dev/null || true
  sleep 0.5
}

capture_window "shell-mac-care-root" -JoeyPetQAOpenMain maccare
capture_window "shell-work-rhythm-root" -JoeyPetQAOpenMain workRhythm
capture_window "shell-mac-care-detail-mock" -JoeyPetQAOpenMain macCareDetail
capture_window "shell-settings-page" -JoeyPetQAOpenMain settings

echo "Done. Layout audit screenshots in $OUT"
