# JoeyPet Release Guide (V0)

Direct distribution for **GitHub Releases** and **Homebrew** (own tap first).
Not Mac App Store. Sandbox stays off per [ADR 011](decisions/011-distribution-and-app-sandbox.md).

## What you must have ready

| Item | Why | How |
|------|-----|-----|
| Apple Developer Program (paid) | Developer ID certificates | [developer.apple.com](https://developer.apple.com) — Account Holder |
| **Developer ID Application** certificate | Gatekeeper accepts the app | Certificates, Identifiers & Profiles → Developer ID Application |
| Team ID | Xcode / `xcodebuild` signing | Membership details page |
| Notary credentials | Upload for notarization | App Store Connect → Users and Access → Integrations → **Team API Key** (preferred), or app-specific password |
| Bundle ID | Stable product identity | Release: `com.zguiyang.JoeyPet` (Debug Dev uses `.dev`) |
| Version + build | Every upload must bump | `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in Xcode |
| Copyright string | About panel / notarization hygiene | Fill `INFOPLIST_KEY_NSHumanReadableCopyright` |
| App icon | Dock / Finder / DMG | Already in Assets; verify Release build |
| Release notes (zh + en optional) | GitHub Release body | What changed, min macOS, install tips |
| Checksums | Homebrew / verify download | `shasum -a 256` of the `.zip` / `.dmg` |

Optional but useful: homepage URL, privacy one-pager (local-first, no account), screenshot for the Release page.

## Signing & notarization (required for Homebrew + normal Gatekeeper)

Apple and Homebrew both expect:

1. **Hardened Runtime** on (`ENABLE_HARDENED_RUNTIME = YES`)
2. Sign with **Developer ID Application** (not Apple Development, not ad-hoc `-`)
3. Submit to Apple Notary Service (`notarytool`)
4. **Staple** the ticket onto the app (and onto the `.dmg` if you ship one)

Without this, users see “unidentified developer”; official `homebrew/cask` will reject / remove such casks (Homebrew 5+ Gatekeeper policy).

### One-time Xcode setup

1. Xcode → Settings → Accounts → add Apple ID → Manage Certificates → **Developer ID Application**.
2. JoeyPet target → Signing & Capabilities:
   - Release: Team = your team; Signing Certificate = Developer ID Application (or Automatic with that team).
   - Enable **Hardened Runtime**.
   - Keep **App Sandbox** off (ADR 011).
3. Add a minimal entitlements file only if notarization logs ask for one. V0 needs no special hardened exceptions (no JIT, no unsigned memory).
4. Fill copyright / category / minimum macOS (target already aims at **14.0**).

### Archive → notarize (Xcode UI)

1. Scheme **JoeyPet**, destination **Any Mac**, configuration **Release**.
2. Product → Archive → Distribute App → **Developer ID** → **Upload**.
3. Wait for notarization → export again so the staple is applied.
4. Quarantine-test on a clean Mac: download the artifact, open normally with Gatekeeper on.

### Archive → notarize (CLI sketch)

```bash
# After a Release archive / signed .app exists:
ditto -c -k --keepParent "JoeyPet.app" JoeyPet.zip

xcrun notarytool submit JoeyPet.zip \
  --key path/to/AuthKey_XXXX.p8 \
  --key-id XXXX \
  --issuer YYYY \
  --wait

xcrun stapler staple JoeyPet.app
spctl --assess --type execute -vv JoeyPet.app
```

Prefer shipping a **zip of the .app** or a **UDIF .dmg** that itself is notarized and stapled. Homebrew casks usually download a zip or dmg from GitHub Releases.

## GitHub Releases checklist

1. Tag from `main` after tests pass: `v1.0.0` (match `MARKETING_VERSION`).
2. Attach:
   - `JoeyPet-1.0.0-macOS.zip` (or `.dmg`)
   - `SHA256SUMS.txt`
3. Release body: min OS, install steps, “signed & notarized with Developer ID”, known limits (e.g. session not restored after quit).
4. Do **not** attach unsigned Debug / “JoeyPet Dev” builds as the primary asset.

## Homebrew path (recommended for V0)

### Phase A — your own tap (ship now)

```text
brew tap <you>/joeypet
brew install --cask joeypet
```

Cask points at the GitHub Release URL + `sha256`. Users get Gatekeeper-clean install without waiting for Homebrew core review.

Minimal cask shape:

```ruby
cask "joeypet" do
  version "1.0.0"
  sha256 "…"

  url "https://github.com/<org>/JoeyPet/releases/download/v#{version}/JoeyPet-#{version}-macOS.zip"
  name "JoeyPet"
  desc "Gentle desktop pet for work rhythm and recovery"
  homepage "https://github.com/<org>/JoeyPet"

  app "JoeyPet.app"

  zap trash: [
    "~/Library/Preferences/com.zguiyang.JoeyPet.plist",
  ]
end
```

Verify locally: `brew audit --cask --online joeypet`, install, launch, Gatekeeper OK.

### Phase B — `homebrew/cask` (later)

Needs notability / public interest. Artefact must pass Gatekeeper (signed + notarized). Prefer native arm64 (or universal); avoid `requires_rosetta` for new casks.

## Repo engineering still missing (do before first public tag)

- [ ] `ENABLE_HARDENED_RUNTIME = YES` on Release
- [ ] Release `DEVELOPMENT_TEAM` / Developer ID signing wired (not only Debug ad-hoc)
- [ ] Copyright Info.plist key filled
- [ ] `macos/scripts/build_joeypet_release.sh` (archive → sign → notarize → staple → zip → sha256)
- [ ] Optional: GitHub Actions that builds on `tag v*` (signing secrets in repo settings)
- [ ] Own Homebrew tap repo + cask
- [ ] Align project-level `MACOSX_DEPLOYMENT_TARGET` with target `14.0` (project currently shows `26.5` from the Xcode host — confusing for CI)

Dev-only path stays: `./macos/scripts/build_joeypet_dev.sh` with `JOEYPET_DEVELOPMENT_TEAM`.

## Product notes for the first release blurb

- Local-first; no account, no cloud, no FDA.
- Companion session is **not** restored after quit (by design today).
- Debug settings / launch args are compiled out of Release UI; do not ship Dev bundle ID to users.

## Verify before publishing

```bash
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' -configuration Release build
xcodebuild -project macos/JoeyPet.xcodeproj -scheme JoeyPet -destination 'platform=macOS' test
codesign -dv --verbose=4 JoeyPet.app
spctl --assess --type execute -vv JoeyPet.app
xcrun stapler validate JoeyPet.app
```

Manual smoke: drag, hide/show, sleep/wake, invite → recover, DND, quiet hours, Gatekeeper first-open dialog.
