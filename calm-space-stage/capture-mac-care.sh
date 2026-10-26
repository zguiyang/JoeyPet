#!/usr/bin/env bash
# Capture the Mac Care Stage prototype preview set into calm-space-stage/previews/mac-care.
#
# NOTE: This uses the app's own offscreen window render (`-JoeyPetQASnapshotOut`), which the
# DEBUG prototype writes to a PNG and then exits. This is the real running prototype window
# rendered in-process — it needs no Screen Recording / TCC and works on a LOCKED display. It
# is NOT a system screenshot (`screencapture`) and NOT an ImageRenderer concept render; it is
# the live prototype window composited to a bitmap. Labels in INDEX.md say so explicitly.
#
# usage: capture-mac-care.sh [app-path]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="${1:-$ROOT/.derived-data/calm-space-qa/Build/Products/Debug/JoeyPet Dev.app}"
OUT="$ROOT/calm-space-stage/previews/mac-care"
mkdir -p "$OUT"
SCALE="$(swift "$ROOT/.orca-backup/tools/display-scale.swift" | awk '{print $1}')"
echo "display scale = $SCALE"

# capture <out-name> <state> <theme> <sizeWxH> [extra-args...]
capture() {
  local name="$1" state="$2" theme="$3" size="$4"; shift 4
  local extra=("$@")
  local dest="$OUT/$name.png"
  rm -f "$dest"
  pkill -x "JoeyPet Dev" 2>/dev/null || true
  sleep 0.4

  open -a "$APP" --args -JoeyPetQAOpenMain maccare -JoeyPetQAStagePrototype macCare \
    -JoeyPetQAStageState "$state" -JoeyPetQAStageFreeze \
    -JoeyPetQAWindowSize "$size" -JoeyPetQATheme "$theme" -JoeyPetQAHidePet \
    -JoeyPetQASnapshotOut "$dest" ${extra[@]+"${extra[@]}"}

  # Poll for the PNG (the app writes then terminates). <= 8s.
  local waited=0
  while [[ ! -s "$dest" && $waited -lt 80 ]]; do sleep 0.1; waited=$((waited+1)); done
  if [[ ! -s "$dest" ]]; then echo "  [FAIL] $name: no PNG after 8s" >&2; return; fi
  sleep 0.2

  # Verify pixel size == points * scale.
  local expect_w expect_h
  expect_w=$(python3 -c "print(round(${size%x*}*$SCALE))")
  expect_h=$(python3 -c "print(round(${size#*x}*$SCALE))")
  python3 - "$dest" "$expect_w" "$expect_h" <<'PY'
import sys
from PIL import Image
p, ew, eh = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
w, h = Image.open(p).size
ok = "ok" if (w, h) == (ew, eh) else "SIZE-MISMATCH"
print(f"  [{ok}] {p.split('/')[-1]}  {w}x{h} (expect {ew}x{eh})")
PY
}

echo "== regular 1024x680 =="
for theme in dark light; do for state in normal attention critical unknown; do
  capture "$state-$theme-1024x680" "$state" "$theme" 1024x680
done; done

echo "== compact 680x512 =="
for theme in dark light; do for state in normal attention; do
  capture "$state-$theme-680x512" "$state" "$theme" 680x512
done; done

echo "== large 1600x900 =="
for theme in dark light; do for state in normal critical; do
  capture "$state-$theme-1600x900" "$state" "$theme" 1600x900
done; done

echo "== activity (1024x680 dark) =="
capture "activity-scanning-dark-1024x680" "normal+scanning" dark 1024x680
capture "activity-complete-dark-1024x680" "normal+complete" dark 1024x680

echo "== long copy (compact attention dark) =="
capture "attention-dark-680x512-longcopy" "attention" dark 680x512 -JoeyPetQAStageLongCopy

echo "== A/B exploration (1024x680 dark) =="
capture "explore-a-1024x680-dark" "normal" dark 1024x680 -JoeyPetQAStageVariant a
capture "explore-b-1024x680-dark" "normal" dark 1024x680 -JoeyPetQAStageVariant b

pkill -x "JoeyPet Dev" 2>/dev/null || true
echo "done -> $OUT"
ls -1 "$OUT" | wc -l | xargs echo "images:"
