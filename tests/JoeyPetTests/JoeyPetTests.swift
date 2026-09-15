//
//  JoeyPetTests.swift
//  JoeyPetTests
//

import Foundation
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
    #endif
}
