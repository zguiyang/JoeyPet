# JoeyPet

[简体中文](./README.zh-CN.md)

A tiny desktop pet that watches over your Mac, reacts to system status, and helps with everyday chores.

JoeyPet is a lightweight, native desktop pet designed to live quietly on your desktop and respond to the state of your computer.

JoeyPet is not an AI companion or chatbot. It focuses on a quiet desktop
presence, three read-only system signals (thermal pressure, memory pressure,
and storage), and a small safety-gated cleanup workflow.

## Current Status

macOS desktop pet MVP in active development.

The first version is focused on macOS and will be built as a native Swift application.

## Documentation

- [AGENTS.md](./AGENTS.md) — rules for coding agents
- [docs/product/](docs/product/) — product Source of Truth: PRD, V1 scope, feature/UI specs, and roadmap
- [docs/](docs/) — technical architecture, sensors, safety, lifecycle, and ADRs

## Principles

- Lightweight and resource-friendly
- Native macOS experience
- Privacy-friendly and local-first
- Read-only system awareness by default
- Safe and explicit confirmation for destructive actions
- Playful interaction without becoming an AI companion
- Small, focused everyday utilities
