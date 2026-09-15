# Safety — Agent Quick Reference

Full doc: [docs/safety.md](../../../../docs/safety.md).

## Pipeline (required for mutating utilities)

```
Observe → Detect → Explain → Recommend → Approve → Act → Feedback
```

## Always confirm

Delete · move · kill process · system settings · Login Items · important folders · any data-loss risk

## Deletion

✅ `FileManager.trashItem` / Move to Trash
❌ `rm -rf`, silent permanent delete, shell scripts without review

## Sensors

Read-only only. If code writes files or kills processes inside a `*Sensor*` type, stop and refactor to `Utilities/`.

## Logging

Use `Logger`; avoid logging full file paths or PII at default privacy in release builds.
