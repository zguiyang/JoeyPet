#!/usr/bin/env bash
# Builds Debug JoeyPet Dev and installs to ~/Applications/JoeyPet Dev.app (no TCC/FDA automation).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="JoeyPet"
CONFIGURATION="Debug"
DERIVED_DATA="${ROOT}/.derived-data/joeypet-dev"
BUILD_DIR="${DERIVED_DATA}/Build/Products/${CONFIGURATION}"
SOURCE_APP="${BUILD_DIR}/JoeyPet Dev.app"
DEST_APP="${HOME}/Applications/JoeyPet Dev.app"

if [[ -z "${JOEYPET_DEVELOPMENT_TEAM:-}" ]]; then
  echo "error: JOEYPET_DEVELOPMENT_TEAM is not set." >&2
  echo "Export your Apple Development Team ID, e.g.:" >&2
  echo "  export JOEYPET_DEVELOPMENT_TEAM=XXXXXXXXXX" >&2
  exit 1
fi

xcodebuild \
  -project "${ROOT}/JoeyPet.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA}" \
  JOEYPET_DEVELOPMENT_TEAM="${JOEYPET_DEVELOPMENT_TEAM}" \
  build

if [[ ! -d "${SOURCE_APP}" ]]; then
  echo "error: expected build product at ${SOURCE_APP}" >&2
  exit 1
fi

mkdir -p "${HOME}/Applications"
# In-place merge/update — no recursive delete; preserves bundle identity and user state under the app container.
ditto "${SOURCE_APP}" "${DEST_APP}"

open "${DEST_APP}"
