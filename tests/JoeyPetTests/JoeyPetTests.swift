//
//  JoeyPetTests.swift
//  JoeyPetTests
//

import Foundation
import SpriteKit
import Testing
@testable import JoeyPet

struct BehaviorEngineTests {
    private let start = Date(timeIntervalSinceReferenceDate: 100_000)

    @Test func thermalWarningMapsToSweating() {
        var engine = BehaviorEngine(now: start)
        let signal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .serious),
            severity: .warning,
            timestamp: start
        )

        let behavior = engine.ingest(signal, now: start)
        #expect(behavior.state == .sweating)
    }

    @Test func memoryWarningMapsToTired() {
        var engine = BehaviorEngine(now: start)
        let signal = SystemSignal(
            sensorID: "memory",
            kind: .memoryPressure(level: .warning),
            severity: .warning,
            timestamp: start
        )

        let behavior = engine.ingest(signal, now: start)
        #expect(behavior.state == .tired)
    }

    @Test func storageLowMapsToCarryingTrash() {
        var engine = BehaviorEngine(now: start)
        let signal = SystemSignal(
            sensorID: "storage",
            kind: .storageLow(
                availableBytes: SensorThresholds.storageCriticalBytes - 1,
                thresholdBytes: SensorThresholds.storageCriticalBytes
            ),
            severity: .critical,
            timestamp: start
        )

        let behavior = engine.ingest(signal, now: start)
        #expect(behavior.state == .carryingTrash)
    }

    @Test func noActiveSignalsReturnsIdle() {
        var engine = BehaviorEngine(now: start)
        let clearThermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .nominal),
            severity: .info,
            timestamp: start
        )

        _ = engine.ingest(clearThermal, now: start)
        let behavior = engine.evaluate(now: start.addingTimeInterval(5))
        #expect(behavior.state == .idle)
    }

    @Test func multipleSignalsUsePriority() {
        var engine = BehaviorEngine(now: start)

        let storage = SystemSignal(
            sensorID: "storage",
            kind: .storageLow(
                availableBytes: SensorThresholds.storageWarningBytes - 1,
                thresholdBytes: SensorThresholds.storageWarningBytes
            ),
            severity: .warning,
            timestamp: start
        )
        let memory = SystemSignal(
            sensorID: "memory",
            kind: .memoryPressure(level: .critical),
            severity: .critical,
            timestamp: start
        )
        let thermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .critical),
            severity: .critical,
            timestamp: start
        )

        _ = engine.ingest(storage, now: start)
        _ = engine.ingest(memory, now: start)
        let behavior = engine.ingest(thermal, now: start)

        #expect(behavior.state == .sweating)
        #expect(behavior.priority == 100)
    }

    @Test func minimumDurationPreventsImmediateDowngrade() {
        let config = BehaviorEngineConfiguration(minimumDisplayDuration: 2.0, reentryCooldown: 3.0)
        var engine = BehaviorEngine(configuration: config, now: start)

        let thermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .serious),
            severity: .warning,
            timestamp: start
        )
        _ = engine.ingest(thermal, now: start)

        let clearThermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .nominal),
            severity: .info,
            timestamp: start.addingTimeInterval(0.5)
        )
        let behavior = engine.ingest(clearThermal, now: start.addingTimeInterval(0.5))

        #expect(behavior.state == .sweating)
    }

    @Test func minimumDurationAllowsDowngradeAfterElapsed() {
        let config = BehaviorEngineConfiguration(minimumDisplayDuration: 2.0, reentryCooldown: 3.0)
        var engine = BehaviorEngine(configuration: config, now: start)

        let thermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .serious),
            severity: .warning,
            timestamp: start
        )
        _ = engine.ingest(thermal, now: start)

        let clearThermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .nominal),
            severity: .info,
            timestamp: start.addingTimeInterval(2.5)
        )
        let behavior = engine.ingest(clearThermal, now: start.addingTimeInterval(2.5))

        #expect(behavior.state == .idle)
    }

    @Test func reentryCooldownPreventsImmediateReturn() {
        let config = BehaviorEngineConfiguration(minimumDisplayDuration: 0.5, reentryCooldown: 3.0)
        var engine = BehaviorEngine(configuration: config, now: start)

        let thermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .serious),
            severity: .warning,
            timestamp: start
        )
        _ = engine.ingest(thermal, now: start)

        let clearThermal = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .nominal),
            severity: .info,
            timestamp: start.addingTimeInterval(1.0)
        )
        _ = engine.ingest(clearThermal, now: start.addingTimeInterval(1.0))
        #expect(engine.currentBehavior.state == .idle)

        let retrigger = SystemSignal(
            sensorID: "thermal",
            kind: .thermalPressure(level: .serious),
            severity: .warning,
            timestamp: start.addingTimeInterval(1.5)
        )
        let blocked = engine.ingest(retrigger, now: start.addingTimeInterval(1.5))
        #expect(blocked.state == .idle)

        let allowed = engine.ingest(retrigger, now: start.addingTimeInterval(4.5))
        #expect(allowed.state == .sweating)
    }
}

struct SensorMappingTests {
    @Test func thermalSensorMapsSeriousToWarningSeverity() {
        let signal = ThermalSensor.makeSignal(from: .serious)
        #expect(signal.severity == .warning)
        #expect(signal.proposedPetState == .sweating)
    }

    @Test func memorySensorMapsWarningToTired() {
        let signal = MemoryPressureSensor.makeSignal(from: .warning)
        #expect(signal.proposedPetState == .tired)
    }

    @Test func storageSensorMapsCriticalThreshold() {
        let signal = StorageSensor.makeSignal(
            for: URL(fileURLWithPath: NSHomeDirectory()),
            now: Date(timeIntervalSinceReferenceDate: 0)
        )
        #expect(signal.severity == .info || signal.severity == .warning || signal.severity == .critical)
    }
}

struct DebugStateInjectorTests {
    #if DEBUG
    @Test func debugSignalFactoryCoversAllStates() {
        for state in PetState.allCases {
            let signal = SystemSignal.debugSignal(for: state)
            let engine = BehaviorEngine(now: Date(timeIntervalSinceReferenceDate: 0))
            var mutableEngine = engine
            let behavior = mutableEngine.ingest(signal, now: Date(timeIntervalSinceReferenceDate: 0))
            if state == .idle {
                #expect(behavior.state == .idle)
            } else {
                #expect(behavior.state == state)
            }
        }
    }

    @Test func parsesDebugPetPackageSpaceSeparatedArgument() {
        let id = DebugStateInjector.packageID(from: ["JoeyPet", "-JoeyPetDebugPet", "JoeyRobot32Candidate"])
        #expect(id == "JoeyRobot32Candidate")
    }

    @Test func parsesDebugPetPackageEqualsArgument() {
        let id = DebugStateInjector.packageID(from: ["-JoeyPetDebugPet=JoeyRobot64Candidate"])
        #expect(id == "JoeyRobot64Candidate")
    }

    @Test func missingDebugPetPackageArgumentReturnsNil() {
        #expect(DebugStateInjector.packageID(from: ["JoeyPet", "-JoeyPetDebugState", "idle"]) == nil)
    }

    @Test func parsesDebugAnimationSpaceSeparatedArgument() {
        let id = DebugStateInjector.animationID(from: ["JoeyPet", "-JoeyPetDebugAnimation", "cleaning"])
        #expect(id == "cleaning")
    }

    @Test func parsesDebugAnimationEqualsArgument() {
        let id = DebugStateInjector.animationID(from: ["-JoeyPetDebugAnimation=notifying"])
        #expect(id == "notifying")
    }

    @Test func missingDebugAnimationArgumentReturnsNil() {
        #expect(DebugStateInjector.animationID(from: ["JoeyPet", "-JoeyPetDebugState", "idle"]) == nil)
        #expect(DebugStateInjector.animationID(from: ["JoeyPet", "-JoeyPetDebugAnimation"]) == nil)
    }

    @Test func parsesDebugBehaviorSpaceSeparatedArgument() {
        let behavior = DebugStateInjector.transientBehavior(
            from: ["JoeyPet", "-JoeyPetDebugBehavior", "blink"]
        )
        #expect(behavior == .blink)
    }

    @Test func parsesDebugBehaviorEqualsArgument() {
        let behavior = DebugStateInjector.transientBehavior(
            from: ["-JoeyPetDebugBehavior=walking"]
        )
        #expect(behavior == .walking)
    }

    @Test func invalidDebugBehaviorArgumentReturnsNil() {
        #expect(
            DebugStateInjector.transientBehavior(
                from: ["JoeyPet", "-JoeyPetDebugBehavior", "not-a-behavior"]
            ) == nil
        )
    }

    @Test func missingDebugBehaviorArgumentReturnsNil() {
        #expect(
            DebugStateInjector.transientBehavior(
                from: ["JoeyPet", "-JoeyPetDebugState", "idle"]
            ) == nil
        )
        #expect(
            DebugStateInjector.transientBehavior(
                from: ["JoeyPet", "-JoeyPetDebugBehavior"]
            ) == nil
        )
    }
    #endif
}

struct PetTransientBehaviorTests {
    @Test func productionTransientBehaviorSemanticsStaySeparated() {
        #expect(PetTransientBehavior.blink.animationID == "blink")
        #expect(PetTransientBehavior.walking.isAmbient)
        #expect(PetTransientBehavior.sleeping.isAmbient)
        #expect(!PetTransientBehavior.cleaning.isAmbient)
        #expect(!PetTransientBehavior.celebrating.isAmbient)
        #expect(!PetTransientBehavior.notifying.isAmbient)
        #expect(PetTransientBehavior.walking.sessionDuration == 2)
        #expect(PetTransientBehavior.cleaning.sessionDuration == 5)
        #expect(PetTransientBehavior.sleeping.sessionDuration == 18)
        #expect(PetTransientBehavior.allCases.count == 6)
    }

    @Test @MainActor func ambientSchedulerStopsDuringSystemStateAndRestartsOnce() {
        let scheduler = AmbientBehaviorScheduler(
            delayProvider: { 0.1 },
            behaviorProvider: { .blink },
            sleeper: { _ in false }
        )

        scheduler.update(sustainedState: .sweating)
        #expect(!scheduler.isRunning)

        scheduler.update(sustainedState: .idle)
        #expect(scheduler.isRunning)
        scheduler.update(sustainedState: .idle)
        #expect(scheduler.isRunning)

        scheduler.stop()
        #expect(!scheduler.isRunning)
    }

    @Test func ambientSchedulerClampsShortDelays() {
        let configuration = AmbientBehaviorScheduler.Configuration(minimumDelay: 12, maximumDelay: 35)
        #expect(AmbientBehaviorScheduler.boundedDelay(0.1, configuration: configuration) == 12)
        #expect(AmbientBehaviorScheduler.boundedDelay(20, configuration: configuration) == 20)
        #expect(AmbientBehaviorScheduler.boundedDelay(60, configuration: configuration) == 35)
    }
}

struct PetManifestTests {
    private func sampleManifest(
        frameWidth: Int = 32,
        frameHeight: Int = 32,
        columns: Int = 4,
        rows: Int = 3,
        defaultScale: Int = 3,
        animations: [String: AnimationClip] = [
            "idle": AnimationClip(frames: [0, 1], fps: 2, loop: true),
            "sweating": AnimationClip(frames: [2, 3, 4], fps: 4, loop: true)
        ]
    ) -> PetManifest {
        PetManifest(
            id: "test-pet",
            name: "Test Pet",
            spriteSheet: "sheet.png",
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            columns: columns,
            rows: rows,
            defaultScale: defaultScale,
            fallbackAnimation: "idle",
            animations: animations
        )
    }

    @Test func decodesManifestAndClipFromJSON() throws {
        let json = """
        {
          "id": "demo",
          "name": "Demo",
          "spriteSheet": "sheet.png",
          "frameWidth": 32,
          "frameHeight": 32,
          "columns": 4,
          "rows": 3,
          "defaultScale": 3,
          "fallbackAnimation": "idle",
          "animations": {
            "idle": { "frames": [0, 1], "fps": 2, "loop": true }
          }
        }
        """
        let manifest = try JSONDecoder().decode(PetManifest.self, from: Data(json.utf8))
        #expect(manifest.id == "demo")
        #expect(manifest.defaultScale == 3)
        #expect(manifest.animations["idle"]?.frames == [0, 1])
        #expect(manifest.animations["idle"]?.fps == 2)
        #expect(manifest.animations["idle"]?.loop == true)
    }

    @Test func defaultScaleIsPreserved() {
        let manifest = sampleManifest(defaultScale: 4)
        #expect(manifest.defaultScale == 4)
    }

    @Test func logicalPointSizeMapsAssetScalePairs() {
        let at3 = sampleManifest(frameWidth: 32, frameHeight: 32, defaultScale: 3)
        #expect(at3.logicalPointSize()?.width == 96)
        #expect(at3.logicalPointSize()?.height == 96)

        let at4 = sampleManifest(frameWidth: 32, frameHeight: 32, defaultScale: 4)
        #expect(at4.logicalPointSize()?.width == 128)
        #expect(at4.logicalPointSize()?.height == 128)

        let dense = sampleManifest(frameWidth: 64, frameHeight: 64, defaultScale: 2)
        #expect(dense.logicalPointSize()?.width == 128)
        #expect(dense.logicalPointSize()?.height == 128)
    }

    @Test func logicalPointSizeRejectsNonPositiveScale() {
        #expect(sampleManifest(defaultScale: 0).logicalPointSize() == nil)
        #expect(sampleManifest(defaultScale: -1).logicalPointSize() == nil)
    }

    @Test func validatesSheetDimensions() {
        let manifest = sampleManifest()
        let error = PetManifestValidator.validate(manifest, sheetPixelWidth: 128, sheetPixelHeight: 96)
        #expect(error == nil)
    }

    @Test func rejectsMismatchedSheetDimensions() {
        let manifest = sampleManifest()
        let error = PetManifestValidator.validate(manifest, sheetPixelWidth: 64, sheetPixelHeight: 96)
        #expect(error == .invalidDimensions(expectedWidth: 128, expectedHeight: 96, actualWidth: 64, actualHeight: 96))
    }

    @Test func rejectsEmptyAnimations() {
        let manifest = sampleManifest(animations: [:])
        let error = PetManifestValidator.validate(manifest, sheetPixelWidth: 128, sheetPixelHeight: 96)
        #expect(error == .emptyAnimations)
    }

    @Test func rejectsNonPositiveDefaultScale() {
        let zeroScale = sampleManifest(defaultScale: 0)
        let zeroError = PetManifestValidator.validate(zeroScale, sheetPixelWidth: 128, sheetPixelHeight: 96)
        #expect(zeroError == .invalidDefaultScale(0))

        let negativeScale = sampleManifest(defaultScale: -1)
        let negativeError = PetManifestValidator.validate(negativeScale, sheetPixelWidth: 128, sheetPixelHeight: 96)
        #expect(negativeError == .invalidDefaultScale(-1))
    }

    @Test func rejectsOutOfBoundsFrameIndex() {
        let manifest = sampleManifest(animations: [
            "idle": AnimationClip(frames: [99], fps: 2, loop: true)
        ])
        let error = PetManifestValidator.validate(manifest, sheetPixelWidth: 128, sheetPixelHeight: 96)
        #expect(error == .outOfBoundsFrame(animationID: "idle", frameIndex: 99, maxIndex: 11))
    }

    @Test func resolvesUnknownAnimationToFallback() {
        let manifest = sampleManifest()
        let resolved = PetManifestValidator.resolvedAnimationID(requestedID: "missing", manifest: manifest)
        #expect(resolved == "idle")
    }

    @Test func nonSquareFrameLayoutCalculation() {
        let manifest = sampleManifest(
            frameWidth: 64,
            frameHeight: 48,
            columns: 2,
            rows: 2,
            animations: [
                "idle": AnimationClip(frames: [0, 1], fps: 2, loop: true),
                "sweating": AnimationClip(frames: [2, 3], fps: 4, loop: true)
            ]
        )
        #expect(manifest.totalFrameCount == 4)
        #expect(manifest.frameRect(for: 0)?.column == 0)
        #expect(manifest.frameRect(for: 0)?.row == 0)
        #expect(manifest.frameRect(for: 1)?.column == 1)
        #expect(manifest.frameRect(for: 1)?.row == 0)
        #expect(manifest.frameRect(for: 2)?.column == 0)
        #expect(manifest.frameRect(for: 2)?.row == 1)
        #expect(manifest.frameRect(for: 3)?.column == 1)
        #expect(manifest.frameRect(for: 3)?.row == 1)
        #expect(manifest.frameRect(for: 4) == nil)

        let error = PetManifestValidator.validate(manifest, sheetPixelWidth: 128, sheetPixelHeight: 96)
        #expect(error == nil)
    }
}

struct PetStateAnimationMappingTests {
    @Test func mapsAllStatesToAnimationIDs() {
        #expect(PetStateAnimationMapping.animationID(for: .idle) == "idle")
        #expect(PetStateAnimationMapping.animationID(for: .sweating) == "sweating")
        #expect(PetStateAnimationMapping.animationID(for: .tired) == "tired")
        #expect(PetStateAnimationMapping.animationID(for: .carryingTrash) == "carryingTrash")
    }
}

struct CleanupTests {
    private let fm = FileManager.default

    private func candidate(path: String, risk: CleanupRisk) -> CleanupCandidate {
        CleanupCandidate(
            id: path,
            url: URL(fileURLWithPath: path),
            displayName: URL(fileURLWithPath: path).lastPathComponent,
            size: 10,
            category: .developerCache,
            risk: risk,
            reason: "test",
            lastModified: nil
        )
    }

    @Test func quickCleanOnlyIncludesSafeCandidates() {
        let safe = candidate(path: "/tmp/safe-cache", risk: .safe)
        let review = candidate(path: "/tmp/review-cache", risk: .review)
        let result = CleanupScanResult(candidates: [safe, review], scannedAt: Date(), skippedCount: 0)

        #expect(result.quickCleanCandidates == [safe])
        #expect(result.reviewCandidates == [review])
    }

    @Test func pathSafetyRejectsOutsideAndSymlinkEscape() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("joeypet-path-test-\(UUID().uuidString)")
        let allowed = root.appendingPathComponent("allowed", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        try fm.createDirectory(at: allowed, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let child = allowed.appendingPathComponent("child")
        try Data("fixture".utf8).write(to: child)
        #expect(CleanupScanner.isSafeCandidate(child, inside: allowed))
        #expect(!CleanupScanner.isSafeCandidate(allowed, inside: allowed))
        #expect(!CleanupScanner.isSafeCandidate(allowed.appendingPathComponent("../outside"), inside: allowed))

        let link = allowed.appendingPathComponent("escape")
        try fm.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(!CleanupScanner.isSafeCandidate(link, inside: allowed))
    }

    @Test @MainActor func scannerFindsFixtureRulesWithoutTouchingUserRoots() async throws {
        let home = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("joeypet-scan-test-\(UUID().uuidString)")
        let derived = home.appendingPathComponent("Library/Developer/Xcode/DerivedData/Fixture", isDirectory: true)
        let logs = home.appendingPathComponent("Library/Logs", isDirectory: true)
        let caches = home.appendingPathComponent("Library/Caches/FixtureApp", isDirectory: true)
        try fm.createDirectory(at: derived, withIntermediateDirectories: true)
        try fm.createDirectory(at: logs, withIntermediateDirectories: true)
        try fm.createDirectory(at: caches, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 16).write(to: derived.appendingPathComponent("derived.data"))
        try Data(repeating: 2, count: 8).write(to: logs.appendingPathComponent("old.log"))
        try Data(repeating: 3, count: 4).write(to: caches.appendingPathComponent("cache.data"))
        let oldDate = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: logs.appendingPathComponent("old.log").path)
        defer { try? fm.removeItem(at: home) }

        let result = await CleanupScanner(homeURL: home).scan()
        #expect(result.candidates.contains { $0.category == .developerCache && $0.risk == .safe })
        #expect(result.candidates.contains { $0.category == .oldLogs && $0.risk == .review })
        #expect(result.candidates.contains { $0.category == .applicationCaches && $0.risk == .review })
    }

    @Test @MainActor func executorReportsPartialFailureWithFakeMover() async {
        let first = candidate(path: "/tmp/first", risk: .safe)
        let second = candidate(path: "/tmp/second", risk: .safe)
        let mover = FakeTrashMover(failingPath: second.url.path)
        let result = await CleanupExecutor().execute([first, second], mover: mover)

        #expect(result.succeededCount == 1)
        #expect(result.failedCount == 1)
        #expect(mover.movedPaths == [first.url.path])
    }
}

private final class FakeTrashMover: FileTrashMoving, @unchecked Sendable {
    private let failingPath: String
    private(set) var movedPaths: [String] = []
    private let lock = NSLock()

    init(failingPath: String) { self.failingPath = failingPath }

    nonisolated func moveToTrash(_ url: URL) throws {
        if url.path == failingPath { throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError) }
        lock.lock()
        movedPaths.append(url.path)
        lock.unlock()
    }
}

@MainActor
struct PetSpriteRuntimeTests {
    private func makeTestPackage() -> LoadedPetPackage {
        let manifest = PetManifest(
            id: "test",
            name: "Test",
            spriteSheet: "sheet.png",
            frameWidth: 1,
            frameHeight: 1,
            columns: 2,
            rows: 1,
            defaultScale: 2,
            fallbackAnimation: "idle",
            animations: [
                "idle": AnimationClip(frames: [0], fps: 2, loop: true),
                "sweating": AnimationClip(frames: [1], fps: 4, loop: true),
                "blink": AnimationClip(frames: [0, 1], fps: 6, loop: false),
                "celebrating": AnimationClip(frames: [0, 1], fps: 4, loop: false)
            ]
        )

        let textureA = SKTexture()
        let textureB = SKTexture()
        textureA.filteringMode = .nearest
        textureB.filteringMode = .nearest

        return LoadedPetPackage(
            manifest: manifest,
            frameTextures: [textureA, textureB],
            clipsByID: manifest.animations
        )
    }

    @Test func sameAnimationDoesNotRestart() {
        let package = makeTestPackage()
        let scene = PetScene(size: CGSize(width: 100, height: 100), package: package)

        scene.applyAnimation("idle")
        let firstAction = scene.children.first?.children.first?.action(forKey: "petAnimation")

        scene.applyAnimation("idle")
        let secondAction = scene.children.first?.children.first?.action(forKey: "petAnimation")

        #expect(firstAction != nil)
        #expect(secondAction === firstAction)
    }

    @Test func runtimePlaysIdleAnimationOnInit() {
        let package = makeTestPackage()
        let runtime = PetRuntime(sceneSize: CGSize(width: 100, height: 100), package: package)

        let action = runtime.scene.children.first?.children.first?.action(forKey: "petAnimation")

        #expect(runtime.currentAnimationID == "idle")
        #expect(action != nil)
    }

    @Test func runtimeForwardsStateToAnimationWithoutRestartingSameClip() {
        let package = makeTestPackage()
        let runtime = PetRuntime(sceneSize: CGSize(width: 100, height: 100), package: package)

        let firstAction = runtime.scene.children.first?.children.first?.action(forKey: "petAnimation")

        runtime.apply(behavior: PetBehavior(
            state: .idle,
            priority: 0,
            triggeringSignal: .thermalPressure(level: .nominal),
            decidedAt: Date()
        ))
        let secondAction = runtime.scene.children.first?.children.first?.action(forKey: "petAnimation")

        #expect(runtime.currentAnimationID == "idle")
        #expect(firstAction != nil)
        #expect(secondAction === firstAction)
    }

    @Test func debugAnimationOverrideDoesNotChangePetState() {
        let package = makeTestPackage()
        let runtime = PetRuntime(sceneSize: CGSize(width: 100, height: 100), package: package)

        runtime.applyDebugAnimation("sweating")

        #expect(runtime.currentState == .idle)
        #expect(runtime.currentAnimationID == "sweating")
    }

    @Test func transientBehaviorStartsAndPreservesUnderlyingState() {
        let package = makeTestPackage()
        let runtime = PetRuntime(sceneSize: CGSize(width: 100, height: 100), package: package)

        #expect(runtime.perform(.celebrating))
        #expect(runtime.currentState == .idle)
        #expect(runtime.currentTransientBehavior == .celebrating)
        #expect(runtime.currentAnimationID == "celebrating")
    }

    @Test func transientBehaviorIsRejectedDuringSystemWarning() {
        let package = makeTestPackage()
        let runtime = PetRuntime(sceneSize: CGSize(width: 100, height: 100), package: package)
        runtime.apply(behavior: PetBehavior(
            state: .sweating,
            priority: 70,
            triggeringSignal: .thermalPressure(level: .serious),
            decidedAt: Date()
        ))

        #expect(!runtime.perform(.blink))
        #expect(!runtime.perform(.celebrating))
        #expect(runtime.currentState == .sweating)
        #expect(runtime.currentAnimationID == "sweating")
    }

    @Test func bundledJoeyRobotPackageLoadsFromAppBundle() {
        PetAssetLoader.resetCacheForTesting()
        let bundle = Bundle(for: PetRuntime.self)
        let result = PetAssetLoader.load(packageID: "JoeyRobot", bundle: bundle)
        #expect(result.isSuccess)
        if case .success(let package) = result {
            #expect(package.manifest.id == "joey-robot")
            #expect(package.manifest.name == "Joey")
            #expect(package.manifest.frameWidth == 32)
            #expect(package.manifest.frameHeight == 32)
            #expect(package.manifest.columns == 10)
            #expect(package.manifest.rows == 3)
            #expect(package.manifest.defaultScale == 4)
            #expect(package.manifest.logicalPointSize()?.width == 128)
            #expect(package.manifest.logicalPointSize()?.height == 128)
            #expect(package.frameTextures.count == 30)
            #expect(package.clipsByID["idle"]?.frames.count == 2)
            let expectedIDs = [
                "idle", "blink", "walking", "sleeping", "sweating",
                "tired", "carryingTrash", "cleaning", "celebrating", "notifying"
            ]
            #expect(package.clipsByID.keys.sorted() == expectedIDs.sorted())
            for (animationID, clip) in package.clipsByID {
                #expect(!clip.frames.isEmpty)
                #expect(clip.fps > 0)
                #expect(clip.frames.allSatisfy { $0 >= 0 && $0 < package.manifest.totalFrameCount })
                #expect(package.manifest.animationClip(for: animationID) == clip)
            }
            #expect(package.manifest.fallbackAnimation == "idle")
            #expect(
                PetManifestValidator.validate(
                    package.manifest,
                    sheetPixelWidth: 320,
                    sheetPixelHeight: 96
                ) == nil
            )
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
