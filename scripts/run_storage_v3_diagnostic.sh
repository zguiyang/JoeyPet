#!/usr/bin/env bash
# Real Storage V3 / FDA integration entry: build, in-place install, and launch JoeyPet Dev.
# Not an XCTest path — grant FDA to JoeyPet Dev in System Settings before expecting V3 scans.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "${ROOT}/scripts/build_joeypet_dev.sh"
