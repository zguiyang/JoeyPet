import Combine
import Foundation
import OSLog

@MainActor
final class PermissionService: ObservableObject {
    static let shared = PermissionService()

    private static let logger = Logger(subsystem: "com.zguiyang.JoeyPet", category: "PermissionService")

    @Published private(set) var fullDiskAccessStatus: FullDiskAccessStatus = .unknown

    var macCareAccessLevel: MacCareAccessLevel {
        MacCareCapability.accessLevel(fullDiskAccessStatus: fullDiskAccessStatus)
    }

    private let probe: any FullDiskAccessProbing
    private let homeURL: URL
    private var refreshTask: Task<Void, Never>?

    init(probe: any FullDiskAccessProbing = FullDiskAccessProbe(), homeURL: URL = URL(fileURLWithPath: NSHomeDirectory())) {
        self.probe = probe
        self.homeURL = homeURL
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.performRefresh()
        }
    }

    func checkFullDiskAccess() {
        refresh()
    }

    private func performRefresh() async {
        let homeURL = homeURL
        let probe = probe
        let outcome = await Task.detached(priority: .utility) {
            probe.probe(homeURL: homeURL)
        }.value

        guard !Task.isCancelled else { return }

        let previous = fullDiskAccessStatus
        fullDiskAccessStatus = outcome.status

        if previous != outcome.status {
            Self.logger.info(
                "Full Disk Access status \(previous.rawValue, privacy: .public) -> \(outcome.status.rawValue, privacy: .public)"
            )
        }

        #if DEBUG
        Self.logger.debug("Full Disk Access capability: \(outcome.status.rawValue, privacy: .public)")
        print("[JoeyPet] Full Disk Access: \(outcome.status.rawValue)")
        #endif
    }
}
