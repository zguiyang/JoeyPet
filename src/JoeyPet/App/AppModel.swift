import Combine
import Foundation
import OSLog

enum MainSection: String, CaseIterable, Hashable, Sendable, Identifiable {
    case overview
    case cleanup
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .cleanup: return "Cleanup"
        case .settings: return "Settings"
        }
    }
}

enum CleanupPhase: Equatable, Sendable {
    case idle
    case scanning
    case ready
    case cleaning
    case completed
    case failed
}

@MainActor
final class AppModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "AppModel")

    @Published var selectedSection: MainSection = .overview
    @Published private(set) var systemStatus = SystemStatusSnapshot.initial
    @Published private(set) var cleanupPhase: CleanupPhase = .idle
    @Published private(set) var scanResult: CleanupScanResult?
    @Published private(set) var executionResult: CleanupExecutionResult?
    @Published private(set) var lastCleanupSummary: CleanupExecutionSummary?
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginError: String?
    @Published var selectedCandidateIDs: Set<String> = []

    private let scanner: CleanupScanner
    private let executor: CleanupExecutor
    private let defaults: UserDefaults
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private var task: Task<Void, Never>?

    var onCleanupStarted: (() -> Void)?
    var onCleanupFinished: ((CleanupExecutionResult) -> Void)?
    var onCleanupEmpty: (() -> Void)?
    var onPreferencesChanged: (() -> Void)?
    var onResetPetPosition: (() -> Void)?

    convenience init() {
        self.init(
            scanner: CleanupScanner(),
            executor: CleanupExecutor(),
            defaults: .standard,
            launchAtLoginManager: LaunchAtLoginManager()
        )
    }

    init(
        scanner: CleanupScanner,
        executor: CleanupExecutor,
        defaults: UserDefaults,
        launchAtLoginManager: any LaunchAtLoginManaging
    ) {
        self.scanner = scanner
        self.executor = executor
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager
        self.lastCleanupSummary = Self.loadSummary(from: defaults)
        self.launchAtLoginEnabled = launchAtLoginManager.isRegistered
        self.launchAtLoginError = nil
    }

    var isBusy: Bool { cleanupPhase == .scanning || cleanupPhase == .cleaning }

    func update(systemStatus: SystemStatusSnapshot) {
        self.systemStatus = systemStatus
    }

    func scan() {
        guard !isBusy else { return }
        task?.cancel()
        cleanupPhase = .scanning
        selectedCandidateIDs.removeAll()
        task = Task { [weak self] in
            guard let self else { return }
            let result = await scanner.scan()
            guard !Task.isCancelled else { return }
            scanResult = result
            executionResult = nil
            cleanupPhase = .ready
        }
    }

    func quickClean() {
        guard !isBusy else { return }
        task?.cancel()
        cleanupPhase = .scanning
        selectedCandidateIDs.removeAll()
        task = Task { [weak self] in
            guard let self else { return }
            let result = await scanner.scan()
            guard !Task.isCancelled else { return }
            scanResult = result
            guard !result.quickCleanCandidates.isEmpty else {
                cleanupPhase = .ready
                onCleanupEmpty?()
                return
            }
            cleanupPhase = .cleaning
            onCleanupStarted?()
            let execution = await executor.execute(result.quickCleanCandidates)
            guard !Task.isCancelled else { return }
            executionResult = execution
            save(summary: CleanupExecutionSummary(execution: execution))
            cleanupPhase = execution.failedCount == execution.items.count ? .failed : .completed
            onCleanupFinished?(execution)
        }
    }

    func executeSelected() {
        guard !isBusy,
              let scanResult else { return }
        let candidates = scanResult.candidates.filter { selectedCandidateIDs.contains($0.id) }
        guard !candidates.isEmpty else { return }
        task?.cancel()
        cleanupPhase = .cleaning
        onCleanupStarted?()
        task = Task { [weak self] in
            guard let self else { return }
            let execution = await executor.execute(candidates)
            guard !Task.isCancelled else { return }
            executionResult = execution
            save(summary: CleanupExecutionSummary(execution: execution))
            cleanupPhase = execution.failedCount == execution.items.count ? .failed : .completed
            onCleanupFinished?(execution)
        }
    }

    func notifyPreferencesChanged() {
        onPreferencesChanged?()
    }

    func resetPetPosition() {
        onResetPetPosition?()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try launchAtLoginManager.setRegistered(enabled)
        } catch {
            launchAtLoginError = enabled
                ? "无法开启开机启动，请检查系统设置。"
                : "无法关闭开机启动，请检查系统设置。"
        }
        launchAtLoginEnabled = launchAtLoginManager.isRegistered
    }

    func cancelOperations() {
        task?.cancel()
        task = nil
        cleanupPhase = .idle
    }

    deinit {
        task?.cancel()
    }

    private func save(summary: CleanupExecutionSummary) {
        lastCleanupSummary = summary
        guard let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: PetPreferences.lastCleanupSummaryKey)
    }

    private static func loadSummary(from defaults: UserDefaults) -> CleanupExecutionSummary? {
        guard let data = defaults.data(forKey: PetPreferences.lastCleanupSummaryKey) else { return nil }
        return try? JSONDecoder().decode(CleanupExecutionSummary.self, from: data)
    }
}
