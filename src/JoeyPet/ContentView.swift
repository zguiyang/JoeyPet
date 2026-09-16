//
//  ContentView.swift
//  JoeyPet
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $model.selectedSection) { section in
                Label(section.title, systemImage: section.iconName)
                    .tag(section)
            }
            .navigationTitle("JoeyPet")
            .frame(minWidth: 170)
        } detail: {
            Group {
                switch model.selectedSection {
                case .overview: OverviewView(model: model)
                case .cleanup: CleanupView(model: model)
                case .settings: SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
    }
}

private extension MainSection {
    var iconName: String {
        switch self {
        case .overview: return "desktopcomputer"
        case .cleanup: return "trash"
        case .settings: return "gearshape"
        }
    }
}

private struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Mac Status").font(.title2.weight(.semibold))
                VStack(spacing: 0) {
                    StatusRow(title: "Thermal", value: model.systemStatus.thermal.displayName, severity: model.systemStatus.thermal.severity)
                    Divider()
                    StatusRow(title: "Memory Pressure", value: model.systemStatus.memory.displayName, severity: model.systemStatus.memory.severity)
                    Divider()
                    StatusRow(title: "Storage", value: storageSummary, severity: model.systemStatus.storageSeverity)
                }
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))

                Text("Cleanup").font(.title2.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    if let result = model.scanResult {
                        Text("Last scan: \(result.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                        Text("Safe cleanup: \(Self.byteFormatter.string(fromByteCount: result.safeSize))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No scan yet")
                            .foregroundStyle(.secondary)
                    }
                    Button("Scan and view") {
                        model.selectedSection = .cleanup
                        model.scan()
                    }
                }
            }
        }
    }

    private var storageSummary: String {
        guard let available = model.systemStatus.storageAvailableBytes,
              let total = model.systemStatus.storageTotalBytes else { return "Unavailable" }
        let free = Self.byteFormatter.string(fromByteCount: available)
        let totalText = Self.byteFormatter.string(fromByteCount: total)
        if let fraction = model.systemStatus.storageUsedFraction {
            return "\(free) free of \(totalText) · \(Int(fraction * 100))% used"
        }
        return "\(free) free of \(totalText)"
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct StatusRow: View {
    let title: String
    let value: String
    let severity: SignalSeverity

    var body: some View {
        HStack {
            Circle().fill(severity.swiftUIColor).frame(width: 9, height: 9)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct CleanupView: View {
    @ObservedObject var model: AppModel
    @State private var showConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleanup").font(.title2.weight(.semibold))
                    Text(statusText).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Scan") { model.scan() }
                    .disabled(model.isBusy)
                Button("Quick Clean") { model.quickClean() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)
            }

            if let result = model.scanResult {
                HStack(spacing: 18) {
                    SummaryValue(title: "Total", value: byteFormatter.string(fromByteCount: result.totalSize))
                    SummaryValue(title: "Safe", value: byteFormatter.string(fromByteCount: result.safeSize))
                    SummaryValue(title: "Review", value: byteFormatter.string(fromByteCount: result.reviewSize))
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(CleanupCategory.allCases, id: \.self) { category in
                            let candidates = result.candidates.filter { $0.category == category }
                            if !candidates.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(category.displayName).font(.headline)
                                    ForEach(candidates) { candidate in
                                        CandidateRow(candidate: candidate, selected: selection(for: candidate))
                                    }
                                }
                            }
                        }
                    }
                }
                Button("Move selected to Trash") { showConfirmation = true }
                    .disabled(model.isBusy || model.selectedCandidateIDs.isEmpty)
                    .confirmationDialog("Move selected items to Trash?", isPresented: $showConfirmation, titleVisibility: .visible) {
                        Button("Move to Trash", role: .destructive) { model.executeSelected() }
                        Button("Cancel", role: .cancel) {}
                    }
            } else if model.cleanupPhase == .scanning {
                ProgressView("Scanning allowed roots…")
            } else {
                ContentUnavailableView("No scan yet", systemImage: "sparkle.magnifyingglass", description: Text("Scan a small set of regenerable caches and old logs."))
            }

            if let execution = model.executionResult {
                Text("Last result: \(execution.succeededCount) moved to Trash, \(execution.failedCount) failed.")
                    .font(.callout)
                    .foregroundStyle(execution.failedCount == 0 ? Color.secondary : Color.orange)
            }
        }
    }

    private var statusText: String {
        switch model.cleanupPhase {
        case .idle: return "Read-only scan of a small allowlist"
        case .scanning: return "Scanning…"
        case .ready: return "Scan complete"
        case .cleaning: return "Moving approved items to Trash…"
        case .completed: return "Cleanup complete"
        case .failed: return "Cleanup finished with errors"
        }
    }

    private func selection(for candidate: CleanupCandidate) -> Binding<Bool> {
        Binding(
            get: { model.selectedCandidateIDs.contains(candidate.id) },
            set: { selected in
                if selected { model.selectedCandidateIDs.insert(candidate.id) }
                else { model.selectedCandidateIDs.remove(candidate.id) }
            }
        )
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    private var byteFormatter: ByteCountFormatter { Self.byteFormatter }
}

private struct CandidateRow: View {
    let candidate: CleanupCandidate
    let selected: Binding<Bool>

    var body: some View {
        Toggle(isOn: selected) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(candidate.displayName)
                    Text(candidate.risk.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(candidate.risk == .safe ? Color.green.opacity(0.15) : Color.orange.opacity(0.15), in: Capsule())
                    Spacer()
                    Text((candidate.sizeIsEstimated ? "~" : "") + ByteCountFormatter.string(fromByteCount: candidate.size, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                Text(candidate.reason).font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
        .padding(10)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("ambientBehaviorsEnabled") private var ambientBehaviorsEnabled = true
    @AppStorage("proactiveBubblesEnabled") private var proactiveBubblesEnabled = true

    var body: some View {
        Form {
            Section("Pet") {
                Toggle("Ambient behaviors", isOn: $ambientBehaviorsEnabled)
            }
            Section("Hints") {
                Toggle("Show proactive bubbles", isOn: $proactiveBubblesEnabled)
            }
        }
        .formStyle(.grouped)
        .onChange(of: ambientBehaviorsEnabled) { _, _ in model.notifyPreferencesChanged() }
        .onChange(of: proactiveBubblesEnabled) { _, _ in model.notifyPreferencesChanged() }
    }
}

private extension ThermalPressureLevel {
    var displayName: String { rawValue.capitalized }
    var severity: SignalSeverity {
        switch self { case .nominal: return .normal; case .fair: return .notice; case .serious: return .warning; case .critical: return .critical }
    }
}

private extension MemoryPressureLevel {
    var displayName: String { rawValue.capitalized }
    var severity: SignalSeverity {
        switch self { case .normal: return .normal; case .warning: return .warning; case .critical: return .critical }
    }
}
