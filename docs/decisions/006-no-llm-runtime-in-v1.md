# ADR 006: No LLM Runtime in V1

## Status

Accepted

## Context

JoeyPet is a desktop pet and lightweight utility assistant, not an AI companion. LLM runtimes add size, latency, cost, and ambiguous safety boundaries for file and system actions.

## Decision

**No LLM runtime in V1.** No LangChain, AI SDK, on-device model bundles, or cloud chat integration for product features.

User-facing copy is templated or rule-based. Explanations for utilities use deterministic text from scan results.

## Consequences

- No prompt engineering or model versioning in the repo for V1.
- “Intelligent” wording comes from structured templates, not generative models.
- Any future AI feature requires a new ADR, privacy review, and safety pipeline extension.
