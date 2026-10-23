# Storage accounting (Analyzer V3)

JoeyPet separates **filesystem explanation** from **volume-level used bytes**.

## Size semantics

| Source | Use |
|--------|-----|
| `URLResourceKey.totalFileAllocatedSize` | Primary allocated / on-disk bytes for regular files |
| `st_blocks * 512` (`lstat`) | Fallback when resource values unavailable |
| `fileSize` | Last-resort logical size |

Rules:

- **Regular files only** — never use directory `totalFileAllocatedSize` as directory size.
- **Directory size** = sum of descendant regular-file allocated bytes (post-order aggregation via scan sum).
- **iCloud / placeholders** — use current local allocation; do not read file bodies or trigger download.
- **APFS clones** — per-file allocated accounting from public APIs; shared physical blocks may be counted on each clone (documented limitation).

## Volume used

From the boot data volume URL (typically `NSHomeDirectory()`):

- `volumeTotalCapacityKey`
- `volumeAvailableCapacityForImportantUsageKey` (preferred) or `volumeAvailableCapacityKey`
- `volumeUsed = total - available`

This is **container/volume accounting**, not guaranteed to equal a full tree walk (snapshots, purgeable space, system volume, metadata).

## Scanned vs classified

- `scannedAllocatedBytes` — sum of unique regular files visited on-scope (hard-link dedup by `(st_dev, st_ino)`).
- Classifier runs **after** scan completes.
- `otherFiles` — scanned bytes with no taxonomy match (classifier remainder).
- `systemReserved` / `accountingGap` — `max(volumeUsed - scannedAllocatedBytes, 0)` when scan ≤ volume used.
- `scanOverrunBytes` — when `scannedAllocatedBytes > volumeUsed` (duplicate / semantics bug; logged, not hidden).

Invariants (tests):

```text
sum(filesystem categories including otherFiles) ≈ scannedAllocatedBytes
scannedAllocatedBytes + accountingGap ≈ volumeUsed   (when no overrun)
```

## Scan scope

- Primary root: `/System/Volumes/Data` when present (boot data volume namespace).
- Skip external mounts under `/Volumes` (other disks).
- Do not follow normal symlinks; follow APFS firmlink sources from `/usr/share/firmlinks`.
- Directory traversal dedup by `(device, inode)`.
- Hidden files **included**.

## Relation to Cleanup

Cleanup Scanner allowlists and safety rules are unrelated to Analyzer scan boundaries.

## Comparison with CLI tools

| Tool | Typical meaning |
|------|-----------------|
| `du` | Often logical or 512-byte block sum depending on flags |
| `df` | Volume block usage |
| `diskutil apfs` | Container / role / snapshot detail |

JoeyPet targets **allocated file bytes** on the data volume plus an explicit **accounting gap** to volume used.
