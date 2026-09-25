#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/scripts/output/gui-qa"
APP="$(
  find "$HOME/Library/Developer/Xcode/DerivedData"/JoeyPet-*/Build/Products/Debug/JoeyPet.app -maxdepth 0 2>/dev/null | head -1
)"
if [[ -z "$APP" ]]; then
  echo "Build JoeyPet Debug first." >&2
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
  local wid
  wid="$(osascript -e 'tell application "System Events" to tell process "JoeyPet" to get id of window 1' 2>/dev/null || true)"
  if [[ -n "$wid" && "$wid" != "missing value" ]]; then
    screencapture -x -l"$wid" "$OUT/$label.png"
    echo "Wrote $OUT/$label.png"
  else
    screencapture -x "$OUT/$label-fullscreen.png"
    echo "Wrote $OUT/$label-fullscreen.png (no window id)"
  fi
  pkill -x JoeyPet 2>/dev/null || true
  sleep 0.5
}

capture_window "01-overview" -JoeyPetQAOpenMain overview
capture_window "02-cleanup-initial" -JoeyPetQAOpenMain cleanup
open -a "$APP" --args -JoeyPetQAOpenMain cleanup -JoeyPetQATriggerScan
sleep 1.2
wid="$(osascript -e 'tell application "System Events" to tell process "JoeyPet" to get id of window 1' 2>/dev/null || true)"
if [[ -n "$wid" && "$wid" != "missing value" ]]; then
  screencapture -x -l"$wid" "$OUT/03-cleanup-scanning.png"
  echo "Wrote $OUT/03-cleanup-scanning.png"
fi
pkill -x JoeyPet 2>/dev/null || true
sleep 0.5

open -a "$APP" --args -JoeyPetQAOpenMain cleanup -JoeyPetQATriggerScan
sleep 10
wid="$(osascript -e 'tell application "System Events" to tell process "JoeyPet" to get id of window 1' 2>/dev/null || true)"
if [[ -n "$wid" && "$wid" != "missing value" ]]; then
  screencapture -x -l"$wid" "$OUT/04-cleanup-results.png"
  echo "Wrote $OUT/04-cleanup-results.png"
fi
pkill -x JoeyPet 2>/dev/null || true
sleep 0.5
capture_window "05-settings" -JoeyPetQAOpenMain settings

open -a "$APP"
sleep 2
osascript <<'APPLESCRIPT' || true
tell application "JoeyPet" to activate
delay 0.8
tell application "System Events"
  tell process "JoeyPet"
    set menuBars to menu bar 1
    repeat with mb in (menu bar items of menuBars)
      try
        if name of mb contains "JoeyPet" or description of mb contains "JoeyPet" then
          click mb
          exit repeat
        end if
      end try
    end repeat
  end tell
end tell
APPLESCRIPT
sleep 0.6
screencapture -x "$OUT/06-menu-bar.png"
echo "Wrote $OUT/06-menu-bar.png"
pkill -x JoeyPet 2>/dev/null || true

echo "Done. Screenshots in $OUT"
