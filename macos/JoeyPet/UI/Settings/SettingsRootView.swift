import AppKit
import SwiftUI

struct SettingsRootView: View {
    @Bindable var settings: AppSettings
    /// Clears the traffic-light band so the sidebar can run full-height.
    var topInset: CGFloat = 0
    /// Only wired in Debug; Release builds never show the Debug section.
    var onDebugAction: ((DebugPetAction) -> Void)?
    @State private var selection: SettingsSection = .rhythm
    @State private var hoveredSection: SettingsSection?
    @State private var isFeedbackOpen = false
    @State private var debugStatus: String = "点一项即可触发完整效果"
    @ScaledMetric(relativeTo: .body) private var feedbackFontSize: CGFloat = 13
    private let audioCatalog = JoeyAudioCatalog.load()
    private let soundPreview = JoeySoundPreviewPlayer()

    private var theme: JoeyTheme {
        JoeyTheme(
            appearance: settings.appearance,
            daypart: settings.appearance == .daypart ? RoomDaypart.resolve(at: Date()) : nil
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(theme.hairline.opacity(0.7))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            // Sidebar stays put; only the detail pane scrolls when Debug (or
            // any future long pane) exceeds the window height.
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    detail
                }
                .padding(.init(top: 20, leading: 28, bottom: 24, trailing: 28))
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.windowBg)
        }
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            HStack(spacing: 0) {
                theme.windowChrome
                    .frame(width: 200)
                theme.windowBg
            }
            .ignoresSafeArea()
        }
        .environment(\.joeyAppearance, settings.appearance)
        .environment(
            \.joeyChromeTone,
            settings.appearance.resolveChromeTone(at: Date())
        )
        .onAppear {
            settings.ambientSoundID = audioCatalog.sanitizedAmbientID(settings.ambientSoundID)
            settings.cueSoundID = audioCatalog.sanitizedCueID(settings.cueSoundID)
        }
        .onDisappear {
            soundPreview.stop()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(SettingsSection.allCases)) { section in
                navRow(section)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.windowChrome)
    }

    private func navRow(_ section: SettingsSection) -> some View {
        let isSelected = selection == section
        let isHovered = hoveredSection == section

        return Button {
            selection = section
        } label: {
            Text(section.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? selectedTextColor : theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? theme.sageSoft : (isHovered ? theme.panel2 : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hoveredSection = $0 ? section : nil }
        .accessibilityLabel(Text(section.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The reference uses sage-deep in light and plain sage in dusk.
    private var selectedTextColor: Color {
        theme.chromeTone == .dark ? theme.sage : theme.sageDeep
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .rhythm:
            rhythmPane
        case .quiet:
            quietPane
        case .appearance:
            appearancePane
        case .about:
            aboutPane
        #if DEBUG
        case .debug:
            debugPane
        #endif
        }
    }

    private var rhythmPane: some View {
        SettingsPane(title: "节奏与提醒", description: "只在你开始工作后提醒。") {
            SettingsRowList {
                SettingsRow("提醒节奏", subtitle: "开始陪伴后才计时") {
                    JoeySegmentedControl(
                        titles: AppSettings.rhythmOptions.map { "\($0) 分钟" },
                        selectedIndex: AppSettings.rhythmOptions.firstIndex(of: settings.rhythmMinutes) ?? 0
                    ) { index in
                        settings.rhythmMinutes = AppSettings.rhythmOptions[index]
                    }
                    .accessibilityLabel("提醒节奏")
                }

                SettingsRow("勿扰模式", subtitle: "开启后不会再有邀请或提示，需要恢复时手动关闭") {
                    JoeySwitch(isOn: $settings.isDoNotDisturb, label: "勿扰模式")
                }

                SettingsRow(
                    "背景音",
                    subtitle: "陪伴中播放；勿扰或安静时段会静音"
                ) {
                    SoundPicker(
                        selection: $settings.ambientSoundID,
                        noneTitle: JoeyAudioCatalog.noneAmbientTitle,
                        tracks: audioCatalog.ambient,
                        kind: .ambient,
                        preview: soundPreview
                    )
                    .accessibilityLabel("背景音")
                }

                SettingsRow(
                    "提示音",
                    subtitle: "开始陪伴与休息邀请时播放；勿扰或安静时段会静音"
                ) {
                    SoundPicker(
                        selection: $settings.cueSoundID,
                        noneTitle: JoeyAudioCatalog.noneCueTitle,
                        tracks: audioCatalog.cues,
                        kind: .cue,
                        preview: soundPreview
                    )
                    .accessibilityLabel("提示音")
                }
            }
        }
    }

    private var quietPane: some View {
        SettingsPane(title: "安静时段", description: "这段时间里 Joey 不会来叫你。") {
            SettingsRowList {
                SettingsRow("安静时段", subtitle: "这段时间不会邀请；正在进行的休息会先走完") {
                    QuietHoursField(
                        startMinutes: $settings.quietStartMinutes,
                        endMinutes: $settings.quietEndMinutes
                    )
                }
            }
        }
    }

    private var appearancePane: some View {
        SettingsPane(title: "外观与位置", description: "Joey 在桌面上的样子。") {
            SettingsRowList {
                SettingsRow("外观", subtitle: "时段跟首页氛围；系统跟 macOS 浅色/深色") {
                    JoeySegmentedControl(
                        titles: JoeyAppearance.allCases.map(\.title),
                        selectedIndex: JoeyAppearance.allCases.firstIndex(of: settings.appearance) ?? 0
                    ) { index in
                        settings.appearance = JoeyAppearance.allCases[index]
                    }
                    .accessibilityLabel("外观")
                }

                SettingsRow("显示位置", subtitle: "拖动后以你放的位置为准") {
                    JoeySegmentedControl(
                        titles: PetCorner.allCases.map(\.title),
                        selectedIndex: PetCorner.allCases.firstIndex(of: settings.petCorner) ?? 0
                    ) { index in
                        settings.petCorner = PetCorner.allCases[index]
                    }
                    .accessibilityLabel("显示位置")
                }

                SettingsRow("在桌面上显示 Joey", subtitle: "关掉不会结束陪伴，到点仍会短暂露面提醒") {
                    JoeySwitch(isOn: $settings.showsDesktopPet, label: "在桌面上显示 Joey")
                }
            }
        }
    }

    #if DEBUG
    private var debugPane: some View {
        SettingsPane(
            title: "Debug",
            description: "仅开发构建可见。Release / 上线包不会出现此页。点击后走完整产品路径（含桌面位移）。"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(debugStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .accessibilityLabel("Debug 状态")

                SettingsRowList {
                    ForEach(DebugPetAction.allCases) { action in
                        SettingsRow(action.title, subtitle: action.subtitle) {
                            SettingsSmallButton(title: "播放") {
                                debugStatus = "已触发：\(action.title)"
                                onDebugAction?(action)
                            }
                            .accessibilityLabel("播放\(action.title)")
                        }
                    }
                }
            }
        }
    }
    #endif

    private var aboutPane: some View {
        SettingsPane(title: "关于 JoeyPet", description: "一只安静生活在桌面上的宠物。") {
            VStack(alignment: .leading, spacing: 0) {
                SettingsRowList {
                    SettingsRow("版本", subtitle: "") {
                        Text(appVersion)
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(theme.ink2)
                    }

                    SettingsRow("反馈", subtitle: "只保存在这台 Mac，不会上传") {
                        SettingsSmallButton(
                            title: isFeedbackOpen ? "收起" : "写一句"
                        ) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                isFeedbackOpen.toggle()
                            }
                        }
                    }

                    if !audioCatalog.attributionTracks.isEmpty {
                        SettingsRow("声音致谢", subtitle: audioAttributionLine) {
                            Text("CC BY")
                                .font(.system(size: 12.5))
                                .foregroundStyle(theme.muted)
                        }
                    }
                }

                if isFeedbackOpen {
                    VStack(alignment: .leading, spacing: 6) {
                        feedbackEditor
                        Text("已自动保存在本机")
                            .font(.caption2)
                            .foregroundStyle(theme.muted)
                            .padding(.leading, 4)
                    }
                    .padding(.top, 14)
                }
            }
        }
    }

    private var feedbackEditor: some View {
        ZStack(alignment: .topLeading) {
            if settings.feedback.isEmpty {
                Text("说给 Joey 听…")
                    .font(.system(size: feedbackFontSize))
                    .foregroundStyle(theme.muted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $settings.feedback)
                .font(.system(size: feedbackFontSize))
                .foregroundStyle(theme.ink)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 72)
                .focusEffectDisabled()
                .accessibilityLabel("反馈")
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.hairlineStrong, lineWidth: 1)
        )
    }

    private var audioAttributionLine: String {
        // Only wind_autumn currently requires credit; keep the line factual.
        "秋叶风 · NickTayloe / Freesound"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Sections

enum SettingsSection: String, Identifiable {
    case rhythm
    case quiet
    case appearance
    case about
    #if DEBUG
    case debug
    #endif

    var id: String { rawValue }

    static var allCases: [SettingsSection] {
        #if DEBUG
        [.rhythm, .quiet, .appearance, .about, .debug]
        #else
        [.rhythm, .quiet, .appearance, .about]
        #endif
    }

    var title: String {
        switch self {
        case .rhythm: return "节奏与提醒"
        case .quiet: return "安静时段"
        case .appearance: return "外观与位置"
        case .about: return "关于 JoeyPet"
        #if DEBUG
        case .debug: return "Debug"
        #endif
        }
    }
}

// MARK: - Layout

private struct SettingsPane<Content: View>: View {
    private let title: String
    private let description: String
    private let content: Content

    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.ink)

            Text(description)
                .font(.system(size: 12.5))
                .foregroundStyle(theme.muted)
                .padding(.top, 4)
                .padding(.bottom, 18)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsRowList<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone

    var body: some View {
        VStack(spacing: 0) {
            content
            Rectangle()
                .fill(JoeyTheme(chromeTone: chromeTone).hairline)
                .frame(height: 1)
        }
    }
}

private struct SettingsRow<Control: View>: View {
    private let title: String
    private let subtitle: String
    private let control: Control

    init(_ title: String, subtitle: String = "", @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 13.5
    @ScaledMetric(relativeTo: .caption) private var subtitleSize: CGFloat = 12
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(theme.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: subtitleSize))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: 20)

            control
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.hairline)
                .frame(height: 1)
        }
    }
}

// MARK: - Controls

/// Menu-style sound chooser: each track has a speaker for audition (settings-only, ignores mute).
private struct SoundPicker: View {
    @Binding var selection: String
    let noneTitle: String
    let tracks: [JoeyAudioTrack]
    let kind: JoeySoundKind
    let preview: JoeySoundPreviewPlayer

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @State private var isOpen = false
    @State private var isHovering = false
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    private var selectedTitle: String {
        if selection == JoeyAudioCatalog.noneID { return noneTitle }
        return tracks.first(where: { $0.id == selection })?.displayNameZh ?? noneTitle
    }

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(selectedTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering || isOpen ? theme.panel2 : theme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.hairlineStrong, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovering = $0 }
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            SoundPickerMenu(
                selection: $selection,
                noneTitle: noneTitle,
                tracks: tracks,
                kind: kind,
                preview: preview,
                onPick: { isOpen = false }
            )
        }
    }
}

private struct SoundPickerMenu: View {
    @Binding var selection: String
    let noneTitle: String
    let tracks: [JoeyAudioTrack]
    let kind: JoeySoundKind
    let preview: JoeySoundPreviewPlayer
    let onPick: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @State private var hoveredID: String?
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    /// Popover ScrollView needs a concrete height or it grows with content and clips.
    private var trackListHeight: CGFloat {
        let rowHeight: CGFloat = 37
        let content = CGFloat(tracks.count) * rowHeight
        let cap: CGFloat = 268
        return min(max(content, rowHeight), cap)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Keep「无」pinned so a long ambient list never hides it.
            menuRow(
                id: JoeyAudioCatalog.noneID,
                title: noneTitle,
                showsSpeaker: false
            )

            insetDivider

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            if index > 0 {
                                insetDivider
                            }
                            menuRow(
                                id: track.id,
                                title: track.displayNameZh,
                                showsSpeaker: true
                            )
                            .id(track.id)
                        }
                    }
                }
                .frame(height: trackListHeight)
                .scrollIndicators(.visible)
                .onAppear {
                    guard selection != JoeyAudioCatalog.noneID,
                          tracks.contains(where: { $0.id == selection })
                    else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(selection, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(6)
        .frame(minWidth: 220)
        .background(theme.panel)
    }

    private var insetDivider: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
            .padding(.horizontal, 10)
    }

    private func menuRow(id: String, title: String, showsSpeaker: Bool) -> some View {
        SoundPickerRow(
            title: title,
            isSelected: selection == id,
            isHovered: hoveredID == id,
            showsSpeaker: showsSpeaker,
            onSelect: {
                selection = id
                if id == JoeyAudioCatalog.noneID {
                    preview.stop()
                } else {
                    playPreview(id: id)
                }
                onPick()
            },
            onPreview: { playPreview(id: id) }
        )
        .onHover { hovering in
            if hovering {
                hoveredID = id
            } else if hoveredID == id {
                hoveredID = nil
            }
        }
    }

    private func playPreview(id: String) {
        switch kind {
        case .ambient:
            preview.previewAmbient(id: id)
        case .cue:
            preview.previewCue(id: id)
        }
    }
}

private struct SoundPickerRow: View {
    let title: String
    let isSelected: Bool
    let isHovered: Bool
    let showsSpeaker: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @State private var speakerHovered = false
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    private var rowFill: Color {
        if isSelected { return theme.panel2 }
        if isHovered { return theme.sageSoft.opacity(0.55) }
        return .clear
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.sageDeep)
                        .opacity(isSelected ? 1 : 0)
                        .frame(width: 14)
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if showsSpeaker {
                Button(action: onPreview) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(speakerHovered ? theme.sageDeep : theme.muted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(speakerHovered ? theme.panel2 : Color.clear)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .onHover { speakerHovered = $0 }
                .padding(.trailing, 6)
                .accessibilityLabel("试听\(title)")
            } else {
                Color.clear
                    .frame(width: 34, height: 28)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(rowFill)
        )
    }
}

private struct JoeySegmentedControl: View {
    let titles: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(titles[index])
                        .font(.system(size: 12, weight: selectedIndex == index ? .semibold : .regular))
                        .foregroundStyle(selectedIndex == index ? theme.ink : theme.ink2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedIndex == index ? theme.panel : Color.clear)
                                .shadow(
                                    color: selectedIndex == index ? .black.opacity(0.06) : .clear,
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                                .shadow(
                                    color: selectedIndex == index ? .black.opacity(0.05) : .clear,
                                    radius: 6,
                                    x: 0,
                                    y: 2
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.panel2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
    }
}

private struct JoeySwitch: View {
    @Binding var isOn: Bool
    let label: String

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? theme.sage : theme.hairlineStrong)

                Circle()
                    .fill(chromeTone == .dark ? Color(hex: 0xE9E3D7) : .white)
                    .frame(width: 17, height: 17)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    .offset(x: isOn ? 17 : 2)
            }
            .frame(width: 36, height: 21)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isOn)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isInside in
            if isInside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .accessibilityRepresentation {
            Toggle(label, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

private struct QuietHoursField: View {
    @Binding var startMinutes: Int
    @Binding var endMinutes: Int

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @State private var startText: String
    @State private var endText: String

    init(startMinutes: Binding<Int>, endMinutes: Binding<Int>) {
        _startMinutes = startMinutes
        _endMinutes = endMinutes
        _startText = State(initialValue: Self.format(startMinutes.wrappedValue))
        _endText = State(initialValue: Self.format(endMinutes.wrappedValue))
    }

    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        HStack(spacing: 6) {
            timeField(label: "安静时段开始", text: $startText)

            Rectangle()
                .fill(theme.hairlineStrong)
                .frame(width: 10, height: 1)

            timeField(label: "安静时段结束", text: $endText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.panel2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        )
        .onChange(of: startMinutes) { _, newValue in
            startText = Self.format(newValue)
        }
        .onChange(of: endMinutes) { _, newValue in
            endText = Self.format(newValue)
        }
    }

    private func timeField(label: String, text: Binding<String>) -> some View {
        TimeRangeTextField(
            label: label,
            text: text,
            textColor: NSColor(theme.ink),
            onCommit: commit
        )
        .frame(width: 44, height: 17)
    }

    private func commit() {
        if let value = Self.parse(startText) {
            startMinutes = value
        }
        startText = Self.format(startMinutes)

        if let value = Self.parse(endText) {
            endMinutes = value
        }
        endText = Self.format(endMinutes)
    }

    private static func format(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private static func parse(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else {
            return nil
        }
        return hour * 60 + minute
    }
}

/// Plain AppKit text field so a double click selects the whole time and typing replaces it.
private struct TimeRangeTextField: NSViewRepresentable {
    let label: String
    @Binding var text: String
    let textColor: NSColor
    let onCommit: () -> Void

    func makeNSView(context: Context) -> TimeRangeNSTextField {
        let field = TimeRangeNSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .center
        field.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        field.textColor = textColor
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.stringValue = text
        field.setAccessibilityLabel(label)
        return field
    }

    func updateNSView(_ nsView: TimeRangeNSTextField, context: Context) {
        context.coordinator.parent = self
        nsView.textColor = textColor
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TimeRangeTextField

        init(_ parent: TimeRangeTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit()
        }
    }
}

private final class TimeRangeNSTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.makeFirstResponder(self)
            if let editor = currentEditor() {
                editor.selectAll(nil)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.currentEditor()?.selectAll(nil)
                }
            }
            return
        }
        super.mouseDown(with: event)
    }
}

private struct SettingsSmallButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.joeyAppearance) private var appearance
    @Environment(\.joeyChromeTone) private var chromeTone
    @State private var isHovering = false
    private var theme: JoeyTheme { JoeyTheme(chromeTone: chromeTone) }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? theme.panel2 : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.hairlineStrong, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovering = $0 }
        .accessibilityLabel(Text(title))
    }
}
