import Combine
import Foundation
import OSLog

/// Resolves which Cleanup page body to show. Scanning/cleaning take priority over stale `scanResult`.
enum CleanupPagePresentation: Equatable, Sendable {
    case initial
    case scanning
    case cleaning
    case nothingToClean
    case results

    static func resolve(phase: CleanupPhase, scanResult: CleanupScanResult?) -> CleanupPagePresentation {
        switch phase {
        case .scanning: return .scanning
        case .cleaning: return .cleaning
        case .idle, .ready, .completed, .failed:
            guard let scanResult else { return .initial }
            if scanResult.candidates.isEmpty { return .nothingToClean }
            return .results
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

    @Published private(set) var systemStatus = SystemStatusSnapshot.initial
    @Published private(set) var memoryTrendSamples: [Double] = []
    @Published private(set) var storageCompositionState: StorageCompositionLoadState = .idle
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
    private let permissionService: PermissionService
    private var task: Task<Void, Never>?
    private var storageCompositionTask: Task<Void, Never>?
    private var permissionObservation: AnyCancellable?
    private let maxMemoryTrendSamples = 48

    var onCleanupStarted: (() -> Void)?
    var onCleanupFinished: ((CleanupExecutionResult) -> Void)?
    var onQuickCleanNeedsConfirmation: (() -> Void)?
    var onQuickCleanNothingToProcess: (() -> Void)?
    var onPreferencesChanged: (() -> Void)?
    var onResetPetPosition: (() -> Void)?

    convenience init() {
        self.init(
            scanner: CleanupScanner(),
            executor: CleanupExecutor(),
            defaults: .standard,
            launchAtLoginManager: LaunchAtLoginManager(),
            permissionService: .shared
        )
    }

    init(
        scanner: CleanupScanner,
        executor: CleanupExecutor,
        defaults: UserDefaults,
        launchAtLoginManager: any LaunchAtLoginManaging,
        permissionService: PermissionService
    ) {
        self.scanner = scanner
        self.executor = executor
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager
        self.permissionService = permissionService
        self.lastCleanupSummary = Self.loadSummary(from: defaults)
        self.launchAtLoginEnabled = launchAtLoginManager.isRegistered
        self.launchAtLoginError = nil

        permissionObservation = permissionService.$fullDiskAccessStatus
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.invalidateStorageComposition()
                self?.refreshStorageCompositionIfNeeded()
            }
    }

    var macCareAccessLevel: MacCareAccessLevel {
        permissionService.macCareAccessLevel
    }

    var isBusy: Bool { cleanupPhase == .scanning || cleanupPhase == .cleaning }

    func update(systemStatus: SystemStatusSnapshot) {
        self.systemStatus = systemStatus
        appendMemoryTrendSample(from: systemStatus)
        refreshStorageCompositionIfNeeded()
    }

    func refreshStorageCompositionIfNeeded() {
        guard let total = systemStatus.storageTotalBytes,
              let available = systemStatus.storageAvailableBytes,
              total > 0
        else { return }

        switch storageCompositionState {
        case .idle, .unavailable:
            break
        case .loading:
            return
        case .loaded(let existing):
            if existing.totalBytes == total, existing.availableBytes == available {
                return
            }
            storageCompositionState = .idle
        }

        storageCompositionState = .loading
        storageCompositionTask?.cancel()
        storageCompositionTask = Task { [weak self] in
            guard let self else { return }
            let accessLevel = permissionService.macCareAccessLevel
            let estimate = await StorageCategoryEstimator.estimate(accessLevel: accessLevel)
            guard !Task.isCancelled else { return }
            let composed = StorageCompositionBuilder.compose(
                totalBytes: total,
                availableBytes: available,
                estimates: estimate.categories
            )
            await MainActor.run {
                guard !Task.isCancelled else { return }
                if let composed {
                    self.storageCompositionState = .loaded(composed)
                } else {
                    self.storageCompositionState = .unavailable
                }
            }
        }
    }

    func invalidateStorageComposition() {
        storageCompositionTask?.cancel()
        storageCompositionState = .idle
    }

    private func appendMemoryTrendSample(from snapshot: SystemStatusSnapshot) {
        guard let used = snapshot.usedMemoryBytes,
              let physical = snapshot.physicalMemoryBytes,
              physical > 0
        else { return }
        let fraction = min(max(Double(used) / Double(physical), 0), 1)
        memoryTrendSamples.append(fraction)
        if memoryTrendSamples.count > maxMemoryTrendSamples {
            memoryTrendSamples.removeFirst(memoryTrendSamples.count - maxMemoryTrendSamples)
        }
    }

    func scan() {
        guard !isBusy else { return }
        task?.cancel()
        cleanupPhase = .scanning
        selectedCandidateIDs.removeAll()
        task = Task { [weak self] in
            guard let self else { return }
            let result = await scanner.scan(
                requestedScope: .deep,
                accessLevel: permissionService.macCareAccessLevel
            )
            guard !Task.isCancelled else { return }
            scanResult = result
            executionResult = nil
            cleanupPhase = .ready
        }
    }

    /// Scans allowlisted roots, then asks for confirmation before moving Safe items to Trash.
    func beginQuickClean() {
        guard !isBusy else { return }
        task?.cancel()
        cleanupPhase = .scanning
        selectedCandidateIDs.removeAll()
        task = Task { [weak self] in
            guard let self else { return }
            let result = await scanner.scan(
                requestedScope: .baseline,
                accessLevel: permissionService.macCareAccessLevel
            )
            guard !Task.isCancelled else { return }
            scanResult = result
            executionResult = nil
            guard !result.quickCleanCandidates.isEmpty else {
                cleanupPhase = .ready
                onQuickCleanNothingToProcess?()
                return
            }
            cleanupPhase = .ready
            onQuickCleanNeedsConfirmation?()
        }
    }

    /// Runs after user confirms Quick Clean; uses Safe items from the latest scan result only.
    func confirmQuickClean() {
        guard !isBusy,
              let scanResult,
              !scanResult.quickCleanCandidates.isEmpty else { return }
        let candidates = scanResult.quickCleanCandidates
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
            invalidateStorageComposition()
            refreshStorageCompositionIfNeeded()
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
            invalidateStorageComposition()
            refreshStorageCompositionIfNeeded()
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
        storageCompositionTask?.cancel()
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
