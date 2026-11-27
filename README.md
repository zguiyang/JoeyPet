# JoeyPet

[简体中文](./README.zh-CN.md)

A quiet desktop pet for gentler work and rest rhythms.

JoeyPet lives on your Mac desktop, keeps you company while you work, and invites short recoveries when the time feels right. It is not a chatbot, task manager, or productivity supervisor — just a small pet that shares the day with you.

## Features

- **Desktop Joey** — drag, hide, and bring him back; stays out of the way by default
- **Work companionship** — you start a session; Joey keeps the rhythm with you
- **Gentle rest invites** — snooze, take a break, or turn on Do Not Disturb
- **Short recoveries** — look far, stand and blink, walk and stretch, or hydrate — copy and duration rotate each invite
- **Shared growth** — the nest and reflection quietly change as you keep company
- **Local-first** — no account, no cloud sync, no analytics

## Download

Latest release: [GitHub Releases](https://github.com/zguiyang/JoeyPet/releases/latest)

| Asset | Use |
|-------|-----|
| `JoeyPet-*-macOS.dmg` | Open the disk image and drag JoeyPet into **Applications** |
| `JoeyPet-*-macOS.zip` | Unzip to get `JoeyPet.app` |

**Requires** macOS 14 or later.

### First launch

macOS may stop the app the first time you open a download. Use either method once:

**Option A — System Settings**

1. Open JoeyPet. If macOS says it can’t be opened, dismiss the dialog.
2. Open **System Settings → Privacy & Security**.
3. Scroll to **Security**. When JoeyPet is listed as blocked, click **Open Anyway**, then confirm.

**Option B — Terminal**

```bash
xattr -cr /Applications/JoeyPet.app
```

If the app is not in Applications yet, use the path where you placed `JoeyPet.app`. Then open JoeyPet normally.

You can also **Control-click** the app → **Open** for the same confirmation flow as Option A.

### After install

Open the nest to get started. Desktop Joey is hidden by default — turn on **Show Joey on Desktop** in Settings or from the menu bar.

## Privacy

Preferences and light stats stay on your Mac (UserDefaults). JoeyPet may use system idle time to notice when you’ve stepped away; it does not read keystrokes or mouse content. Feedback uses mailto — nothing is uploaded in the background.

## Build from source

```bash
open macos/JoeyPet.xcodeproj
```

Use the **JoeyPet** scheme, **Release** configuration, destination **My Mac**.

## Repository layout

```text
macos/        macOS app (Xcode project, Swift sources, tests, platform scripts)
docs/         product, design, and ADR documentation
.agents/      repository agent skills
```

## Documentation

- [AGENTS.md](./AGENTS.md) — agent development rules
- [DESIGN.md](./DESIGN.md) — native UI/UX design contract
- [UI reference](./docs/reference/joeypet-ui-v0.html) — frozen visual target
- [V0_FEATURE_SCOPE.md](./V0_FEATURE_SCOPE.md) — product scope
- [开发交接文档.md](./开发交接文档.md) — handoff notes

## Principles

- Lightweight and resource-friendly
- Native macOS experience
- Privacy-friendly and local-first
- Playful without becoming an AI companion
- Gentle reminders without supervision or pressure
