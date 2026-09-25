import SwiftUI

struct LegacyCleanupView: View {
    @ObservedObject var model: AppModel
    @State private var showConfirmation = false

    private var presentation: CleanupPagePresentation {
        CleanupPagePresentation.resolve(phase: model.cleanupPhase, scanResult: model.scanResult)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("清理")
                .font(.title2.weight(.semibold))
            headerRow

            Group {
                    switch presentation {
                    case .initial:
                        initialBody
                    case .scanning:
                        busyBody(title: "正在扫描…", subtitle: "只读取允许范围内的缓存和日志，不会改动文件。")
                    case .cleaning:
                        busyBody(title: "正在移到废纸篓…", subtitle: "请稍候，不要重复操作。")
                    case .nothingToClean:
                        nothingToCleanBody
                    case .results:
                        resultsBody
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            outcomeFooter
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(phaseSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if showsToolbarActions {
                HStack(spacing: 10) {
                    if showsQuickClean {
                        Button("快速清理") { model.beginQuickClean() }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy)
                    }
                    if presentation == .initial {
                        Button("扫描") { model.scan() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isBusy)
                    } else {
                        Button("扫描") { model.scan() }
                            .buttonStyle(.bordered)
                            .disabled(model.isBusy)
                    }
                }
            }
        }
    }

    private var showsToolbarActions: Bool {
        switch presentation {
        case .scanning, .cleaning: return false
        case .initial, .nothingToClean, .results: return true
        }
    }

    private var showsQuickClean: Bool {
        guard let result = model.scanResult else { return false }
        return presentation == .results && result.safeSize > 0
    }

    private var phaseSubtitle: String {
        switch presentation {
        case .initial:
            return "扫描 Xcode 缓存、旧日志和应用缓存，确认后再移到废纸篓。"
        case .scanning:
            return "正在扫描"
        case .cleaning:
            return "正在处理"
        case .nothingToClean:
            return "扫描完成"
        case .results:
            return "扫描完成，请确认要处理的项目。"
        }
    }

    private var initialBody: some View {
        ContentUnavailableView {
            Label("尚未扫描", systemImage: "sparkle.magnifyingglass")
        } description: {
            Text("扫描允许范围内的缓存和日志。")
        } actions: {
            Button("扫描") { model.scan() }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy)
        }
    }

    private func busyBody(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressView(title)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var nothingToCleanBody: some View {
        ContentUnavailableView {
            Label("暂时没有需要清理的内容", systemImage: "checkmark.circle")
        } description: {
            Text("你的 Mac 目前很干净。可以稍后再扫描一次。")
        } actions: {
            Button("重新扫描") { model.scan() }
                .disabled(model.isBusy)
        }
    }

    @ViewBuilder
    private var resultsBody: some View {
        if let result = model.scanResult {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 24) {
                    SummaryValue(title: "可释放", value: JoeyByteFormat.string(fromByteCount: result.totalSize))
                    SummaryValue(title: "可快速处理", value: JoeyByteFormat.string(fromByteCount: result.safeSize))
                    SummaryValue(title: "建议先查看", value: JoeyByteFormat.string(fromByteCount: result.reviewSize))
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        candidateSection(
                            title: "可快速处理",
                            subtitle: "可由「快速清理」移到废纸篓",
                            candidates: result.safeCandidates,
                            allowsSelection: false
                        )
                        candidateSection(
                            title: "建议先查看",
                            subtitle: "勾选后移到废纸篓",
                            candidates: result.reviewCandidates,
                            allowsSelection: true
                        )
                    }
                }

                if !result.reviewCandidates.isEmpty {
                    Button("将所选移到废纸篓") { showConfirmation = true }
                        .disabled(model.isBusy || model.selectedCandidateIDs.isEmpty)
                        .confirmationDialog(
                            "将所选项目移到废纸篓？",
                            isPresented: $showConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("移到废纸篓", role: .destructive) { model.executeSelected() }
                            Button("取消", role: .cancel) {}
                        } message: {
                            Text("可在废纸篓中恢复这些文件。")
                        }
                }
            }
        }
    }

    private func candidateSection(
        title: String,
        subtitle: String,
        candidates: [CleanupCandidate],
        allowsSelection: Bool
    ) -> some View {
        Group {
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(candidates) { candidate in
                        CandidateRow(
                            candidate: candidate,
                            selected: selection(for: candidate),
                            allowsSelection: allowsSelection
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var outcomeFooter: some View {
        if presentation != .scanning && presentation != .cleaning {
            if let execution = model.executionResult {
                StatusLabel(
                    severity: execution.failedCount == 0 ? .normal : .warning,
                    text: executionOutcomeText(execution)
                )
                .font(.callout)
            } else if let summary = model.lastCleanupSummary, presentation != .initial {
                StatusLabel(
                    severity: summary.failedCount == 0 ? .normal : .warning,
                    text: lastSummaryText(summary)
                )
                .font(.callout)
            }
        }
    }

    private func executionOutcomeText(_ execution: CleanupExecutionResult) -> String {
        let bytes = JoeyByteFormat.string(fromByteCount: execution.movedBytes)
        if execution.failedCount == 0 {
            return "本次已将 \(execution.succeededCount) 项移到废纸篓（约 \(bytes)）。"
        }
        return "已移到废纸篓 \(execution.succeededCount) 项，\(execution.failedCount) 项失败（约 \(bytes)）。"
    }

    private func lastSummaryText(_ summary: CleanupExecutionSummary) -> String {
        let time = summary.finishedAt.formatted(date: .abbreviated, time: .shortened)
        let bytes = JoeyByteFormat.string(fromByteCount: summary.movedBytes)
        if summary.failedCount == 0 {
            return "上次清理：\(time)，\(summary.succeededCount) 项移到废纸篓（约 \(bytes)）。"
        }
        return "上次清理：\(time)，成功 \(summary.succeededCount) 项，失败 \(summary.failedCount) 项。"
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
}

private struct CandidateRow: View {
    let candidate: CleanupCandidate
    let selected: Binding<Bool>
    let allowsSelection: Bool

    var body: some View {
        Group {
            if allowsSelection {
                Toggle(isOn: selected) {
                    rowContent
                }
                .toggleStyle(.checkbox)
            } else {
                rowContent
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.displayName)
                    .font(.body)
                Spacer()
                Text(sizeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(candidate.category.uiDisplayName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var sizeText: String {
        let prefix = candidate.sizeIsEstimated ? "约 " : ""
        return prefix + JoeyByteFormat.string(fromByteCount: candidate.size)
    }
}

private struct SummaryValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

