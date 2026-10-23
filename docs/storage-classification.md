# Storage classification (Mac Care)

JoeyPet storage composition is **not** Apple System Settings → Storage. It uses **known-root, non-overlapping** walks on the boot volume plus a remainder bucket.

## Size metric

All categories use **`URLResourceKey.totalFileAllocatedSize`** (APFS allocated blocks / on-disk footprint), falling back to **`fileSize`** when allocation is unavailable. This matches “how much disk space is used” better than logical size alone.

Application bundles (`.app`) are walked recursively because bundle directories do not report allocated size at the package root.

## Taxonomy (Full Disk Access granted)

| Category | Roots | Notes |
|----------|-------|--------|
| Applications | `/Applications`, `~/Applications` | Top-level `.app` bundles only |
| Documents | `~/Documents`, `~/Desktop`, `~/Downloads` | User-visible folders |
| Photos | `~/Pictures` | Includes photo libraries as packages |
| Videos | `~/Movies` | |
| Audio | `~/Music` | |
| Developer | `~/Library/Developer` | |
| Caches | `~/Library/Caches` | Not counted under Application Data |
| Application Data | `~/Library/Application Support`, `~/Library/Containers`, `~/Library/Group Containers` | |
| System & Other | Remainder | `used − sum(classified)` after scan completes |

## Limited mode (no FDA)

Applications (best effort), Developer, and Caches only. No Documents / Photos / Videos / Audio / Application Data scans (avoids incomplete TCC-gated reads).

## Lifecycle

- Background utility-priority scan; progressive categories published during scan.
- **System & Other** is computed only after all planned categories finish (`includeSystemRemainder: true`).
- While scanning, unclassified used space appears as **分析中**, not **系统与其他**.
- Results cached ~6 hours; invalidated on FDA change, cleanup completion, or volume total/available change.

## Coverage

`coverage = classifiedUsedBytes / usedBytes` (excluding remainder). Logged at info level for quality checks.

## Limitations

- No full-volume recursive scan of `/`.
- Bounded entry counts per root may mark classification **partial**.
- APFS snapshots, purgeable space, system volume, and shared clones may differ from macOS Settings totals.
- Remainder includes inaccessible paths and unclassified used space by design.
