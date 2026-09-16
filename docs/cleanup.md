# Cleanup MVP

JoeyPet's first cleanup utility is deliberately small and local. The scanner is
read-only and only inspects these user-library roots:

- `~/Library/Developer/Xcode/DerivedData` — child directories, `safe`, because Xcode can regenerate them.
- `~/Library/Logs` — ordinary files older than 30 days, `review`, because logs may still be useful.
- `~/Library/Caches` — direct child directories, `review`, because an application may be using them.

The scanner never walks `/`, system directories, Applications, Documents,
Desktop, Downloads, Pictures, Music, Movies, or iCloud Drive. It does not
follow symbolic links and each candidate is canonically checked against its
allowlisted root.

The app target does not use App Sandbox because macOS would otherwise hide the
three allowlisted user-library roots from a normal scan. JoeyPet does not
request Full Disk Access or sudo; read and write scope is constrained by the
scanner allowlist and the explicit cleanup controls.

`CleanupCandidate` carries an id, path, display name, byte size, category,
risk, reason, and optional modification date. `safe` candidates are eligible
for Quick Clean. `review` candidates appear in the Cleanup page and require
explicit selection.

Quick Clean is the explicit approval control for the safe set. It rescans,
filters to `safe`, and moves only that set to the macOS Trash. It never includes
review items and never empties Trash. Selected items use a short confirmation
before the same Trash workflow. Scanner and Executor are separate, so a scan
cannot perform file changes accidentally.

Execution supports partial success. The Cleanup page reports moved and failed
items, while user-facing messages stay short; technical errors are logged
without file contents. Permission errors and disappeared files are reported as
individual failures rather than crashing or rolling back successful moves.
Directory sizes use a one-level, 256-entry bounded estimate (shown with `~`)
so a scan does not recursively traverse an unbounded cache; the candidate
itself remains explicitly scoped to the allowlisted root.

Tests use temporary fixture directories and a fake Trash mover. No test targets
the real user cache or log directories.
