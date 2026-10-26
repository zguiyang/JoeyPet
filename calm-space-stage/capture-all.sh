#!/usr/bin/env bash
# Capture the full Stage preview set (Work Rhythm + revised Mac Care) via the app's own
# offscreen window render (`-JoeyPetQASnapshotOut`). This is the real running prototype
# window composited to a bitmap in-process — it needs no Screen Recording / TCC and works
# on a LOCKED display. NOT a system screenshot, NOT an ImageRenderer concept render.
#
# usage: capture-all.sh [app-path]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="${1:-$ROOT/.derived-data/calm-space-qa/Build/Products/Debug/JoeyPet Dev.app}"
MC="$ROOT/calm-space-stage/previews/mac-care"
WR="$ROOT/calm-space-stage/previews/work-rhythm"
mkdir -p "$MC" "$WR"
SCALE="$(swift "$ROOT/.orca-backup/tools/display-scale.swift" | awk '{print $1}')"
echo "display scale = $SCALE"

# capture <mode> <outdir> <name> <state> <theme> <sizeWxH> [extra-args...]
capture() {
  local mode="$1" outdir="$2" name="$3" state="$4" theme="$5" size="$6"; shift 6
  local extra=("$@")
  local dest="$outdir/$name.png"
  rm -f "$dest"
  pkill -x "JoeyPet Dev" 2>/dev/null || true
  sleep 0.4

  open -a "$APP" --args -JoeyPetQAOpenMain maccare -JoeyPetQAStagePrototype "$mode" \
    -JoeyPetQAStageState "$state" -JoeyPetQAStageFreeze \
    -JoeyPetQAWindowSize "$size" -JoeyPetQATheme "$theme" -JoeyPetQAHidePet \
    -JoeyPetQASnapshotOut "$dest" ${extra[@]+"${extra[@]}"}

  local waited=0
  while [[ ! -s "$dest" && $waited -lt 80 ]]; do sleep 0.1; waited=$((waited+1)); done
  if [[ ! -s "$dest" ]]; then echo "  [FAIL] $name: no PNG after 8s" >&2; return; fi
  sleep 0.2

  local ew eh
  ew=$(python3 -c "print(round(${size%x*}*$SCALE))")
  eh=$(python3 -c "print(round(${size#*x}*$SCALE))")
  python3 - "$dest" "$ew" "$eh" <<'PY'
import sys
from PIL import Image
p, ew, eh = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
w, h = Image.open(p).size
ok = "ok" if (w, h) == (ew, eh) else "SIZE-MISMATCH"
print(f"  [{ok}] {p.split('/')[-1]}  {w}x{h} (expect {ew}x{eh})")
PY
}

echo "== Work Rhythm 1024x680 =="
for theme in dark light; do for state in idle focus paused rest complete; do
  capture workRhythm "$WR" "$state-$theme-1024x680" "$state" "$theme" 1024x680
done; done

echo "== Work Rhythm 680x512 =="
for state in idle focus paused; do capture workRhythm "$WR" "$state-dark-680x512" "$state" dark 680x512; done
for state in idle focus; do capture workRhythm "$WR" "$state-light-680x512" "$state" light 680x512; done

echo "== Work Rhythm 1600x900 =="
for theme in dark light; do for state in focus rest; do
  capture workRhythm "$WR" "$state-$theme-1600x900" "$state" "$theme" 1600x900
done; done

echo "== Work Rhythm special =="
capture workRhythm "$WR" "focus-longcopy-680x512-dark" "focus" dark 680x512 -JoeyPetQAStageLongCopy
capture workRhythm "$WR" "focus-staticui-1024x680-dark" "focus" dark 1024x680 -JoeyPetQAStaticUI

echo "== Mac Care (revised) 1024x680 =="
for theme in dark light; do for state in normal attention critical unknown; do
  capture macCare "$MC" "$state-$theme-1024x680" "$state" "$theme" 1024x680
done; done
echo "== Mac Care compact 680x512 =="
for theme in dark light; do for state in normal attention; do
  capture macCare "$MC" "$state-$theme-680x512" "$state" "$theme" 680x512
done; done
echo "== Mac Care large 1600x900 =="
for theme in dark light; do for state in normal critical; do
  capture macCare "$MC" "$state-$theme-1600x900" "$state" "$theme" 1600x900
done; done
echo "== Mac Care activity/longcopy/A-B =="
capture macCare "$MC" "activity-scanning-dark-1024x680" "normal+scanning" dark 1024x680
capture macCare "$MC" "activity-complete-dark-1024x680" "normal+complete" dark 1024x680
capture macCare "$MC" "attention-dark-680x512-longcopy" "attention" dark 680x512 -JoeyPetQAStageLongCopy
capture macCare "$MC" "explore-a-1024x680-dark" "normal" dark 1024x680 -JoeyPetQAStageVariant a
capture macCare "$MC" "explore-b-1024x680-dark" "normal" dark 1024x680 -JoeyPetQAStageVariant b

pkill -x "JoeyPet Dev" 2>/dev/null || true
echo "done. work-rhythm=$(ls "$WR" | wc -l)  mac-care=$(ls "$MC" | wc -l)"
