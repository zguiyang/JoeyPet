# JoeyPet

[简体中文](./README.zh-CN.md)

A tiny desktop pet that quietly accompanies healthy work rhythms.

JoeyPet is a lightweight, native desktop pet designed to live quietly on your desktop and gently invite short recovery breaks.

JoeyPet is not an AI companion or chatbot. It focuses on a quiet desktop
presence, gentle work-rhythm companionship and a small sense of shared growth.

## Download

Latest build: [GitHub Releases](https://github.com/zguiyang/JoeyPet/releases/latest)

- **Preferred:** `JoeyPet-*-macOS.dmg` — open and drag JoeyPet into Applications
- Or: `JoeyPet-*-macOS.zip` — unzip to get `JoeyPet.app`

**Requires** macOS 14 or later.

### First launch

macOS may block apps downloaded from the internet until you confirm once:

1. Open the app. If macOS says it can’t be opened, dismiss that dialog.
2. Go to **System Settings → Privacy & Security**, scroll to **Security**.
3. When JoeyPet is listed as blocked, click **Open Anyway**, then confirm.

You can also **Control-click** `JoeyPet.app` → **Open** to get the same confirmation flow.

After install, open the nest to start. Desktop Joey stays hidden by default — turn on “Show Joey on Desktop” in Settings or the menu bar.

## Repository Layout

```text
macos/        macOS app (Xcode project, Swift sources, tests, platform scripts)
docs/         shared product, design and ADR documentation
.agents/      repository-level agent skills
```

## Documentation

- [AGENTS.md](./AGENTS.md) — rules for coding agents
- [DESIGN.md](./DESIGN.md) — V0 native UI/UX design contract
- [V0 UI reference](./docs/reference/joeypet-ui-v0.html) — frozen visual target
- [V0_FEATURE_SCOPE.md](./V0_FEATURE_SCOPE.md) — current test-version product scope
- [开发交接文档.md](./开发交接文档.md) — current handoff and development boundary

## Principles

- Lightweight and resource-friendly
- Native macOS experience
- Privacy-friendly and local-first
- Playful interaction without becoming an AI companion
- Gentle reminders without supervision or pressure
