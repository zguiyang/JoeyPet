# System Sensors

Current sensor implementation is **read-only**. Each implemented sensor
produces `SystemSignal` values; none drives UI directly.

The product V1 System Overview target is broader than the currently
implemented semantic sensors. Product scope is defined in
[`docs/product/mvp-scope.md`](product/mvp-scope.md) and [`docs/product/feature-spec.md`](product/feature-spec.md);
this technical document records implementation facts and does not expand the
scope by itself.

| V1 Overview target | Current implementation | Product note |
|---|---|---|
| CPU Usage | Missing | Required for Overview; short trend where meaningful |
| Memory Usage | Missing | Required and separate from Memory Pressure |
| Memory Pressure | Done | Semantic health signal and Joey reaction |
| Storage Usage | Done | Current used/free/total data and low-space signal |
| Network Activity | Missing | Download/upload and short trend |
| Thermal State | Done | Semantic state and Joey reaction; not CPU temperature |
| Fan RPM | Conditional | Show only after reliable technical validation |
| Exact Temperature | Conditional | Never infer from Thermal State |

## Shared principles

- Event-driven where Apple provides notifications; polling only when necessary.
- Conservative poll intervals to limit wakeups and CPU use.
- Document permissions and sandbox limits per sensor.
- `thermalState` reflects **thermal pressure level**, not exact CPU temperature in °C.

---

## ThermalSensor

| Item | Detail |
|------|--------|
| **Purpose** | Detect elevated thermal pressure for pet “hot / sweating” states |
| **Data source** | `ProcessInfo.processInfo.thermalState` |
| **Apple API** | `ProcessInfo.ThermalState` (`nominal`, `fair`, `serious`, `critical`) |
| **Delivery** | Event-driven via `ProcessInfo.thermalStateDidChangeNotification` |
| **Polling fallback** | Optional low-frequency poll (e.g. 30–60 s) if notifications missed |
| **Output** | `SystemSignal` with severity mapped from thermal state; payload includes raw enum |
| **Permissions** | None beyond normal app execution |
| **Limits** | Coarse system-wide state; not per-process CPU temperature |

---

## MemoryPressureSensor

| Item | Detail |
|------|--------|
| **Purpose** | Detect memory pressure for pet “tired / sluggish” states |
| **Data source** | Memory pressure dispatch source |
| **Apple API** | `DispatchSource.makeMemoryPressureSource(eventMask: .all, queue:)` |
| **Delivery** | Event-driven |
| **Polling fallback** | None required when dispatch source active |
| **Output** | `SystemSignal` with severity from pressure level (`normal`, `warning`, `critical`) |
| **Permissions** | None for pressure events |
| **Limits** | Indicates pressure, not exact free RAM bytes unless supplemented later |

---

## StorageSensor

| Item | Detail |
|------|--------|
| **Purpose** | Detect low free space or target-volume thresholds for pet + cleanup hints |
| **Data source** | File system attributes for user home or selected volumes |
| **Apple API** | `URLResourceKey.volumeAvailableCapacityForImportantUsageKey`, `volumeAvailableCapacityKey`; `FileManager.attributesOfFileSystem(forPath:)` |
| **Delivery** | Polling on interval (e.g. 5–15 min) or on app foreground / utility scan |
| **Output** | `SystemSignal` when free space below configured thresholds |
| **Permissions** | Read-only volume metadata; no FDA required. Deep storage classification is gated separately—see [permissions.md](permissions.md) |
| **Limits** | Threshold-based; not a continuous byte stream |

---

## Idle / Active Duration Sensor (Not Implemented; Not in V1)

This is a future V1.1 candidate, not a current JoeyPet sensor or MVP
requirement. The following notes preserve the earlier exploration without
claiming that the capability exists.

| Item | Detail |
|------|--------|
| **Purpose** | Track continuous active vs idle time for break reminders |
| **Data source** | User input idle detection + app active session clock |
| **Apple API** | `CGEventSource.secondsSinceLastEventType` (idle); `NSWorkspace` notifications / app lifecycle for active session |
| **Delivery** | Timer-based evaluation (e.g. every 60 s) while app running |
| **Output** | `SystemSignal` when active duration exceeds threshold; optional idle signal |
| **Permissions** | Accessibility not required for basic idle timing; document if extended input monitoring added |
| **Limits** | Approximate idle detection; respect user “do not disturb” preferences |

---

## Signal → behavior

Sensors emit `SystemSignal` only. Mapping to `PetBehavior` / `PetState` happens in the behavior engine. See [architecture.md](architecture.md) and [decisions/005-read-only-sensors-by-default.md](decisions/005-read-only-sensors-by-default.md).

## Related docs

- [domain-model.md](domain-model.md)
- [safety.md](safety.md)
