import SwiftUI

struct SettingsPageHeader: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: SettingsMetrics.pageTitleFontSize, weight: .semibold))
                .foregroundStyle(.primary)
            Text(description)
                .font(.system(size: SettingsMetrics.pageDescriptionFontSize))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 24)
    }
}

struct SettingsSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: SettingsMetrics.sectionTitleFontSize, weight: .semibold))
            .foregroundStyle(.tertiary)
            .kerning(0.4)
            .padding(.top, SettingsMetrics.sectionTopSpacing)
            .padding(.bottom, 8)
    }
}

struct SettingsFormRow<Trailing: View>: View {
    let title: String
    let description: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: SettingsMetrics.rowTitleFontSize, weight: .medium))
                    .foregroundStyle(.primary)
                if let description {
                    Text(description)
                        .font(.system(size: SettingsMetrics.rowDescriptionFontSize))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.vertical, SettingsMetrics.rowVerticalPadding)
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider()
    }
}

struct SettingsDetailFooter: View {
    let resetTitle: String
    var onReset: (() -> Void)?

    var body: some View {
        HStack {
            if let onReset {
                Button(resetTitle, action: onReset)
                    .buttonStyle(.plain)
                    .font(.system(size: SettingsMetrics.pageDescriptionFontSize))
                    .foregroundStyle(.secondary)
            } else {
                Button(resetTitle) {}
                    .buttonStyle(.plain)
                    .font(.system(size: SettingsMetrics.pageDescriptionFontSize))
                    .foregroundStyle(.secondary)
                    .disabled(true)
            }
            Spacer()
            Text("修改已实时生效")
                .font(.system(size: SettingsMetrics.pageDescriptionFontSize))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, SettingsMetrics.footerTopSpacing)
    }
}

/// Shared sidebar row chrome for Settings navigation (back + sections).
struct SettingsSidebarNavigationRow: View {
    let systemImage: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: SettingsMetrics.sidebarIconSize, height: SettingsMetrics.sidebarIconSize)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, SettingsMetrics.sidebarPadding)
            .frame(height: SettingsMetrics.sidebarRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: SettingsMetrics.sidebarRowCornerRadius, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.85))
            .contentShape(RoundedRectangle(cornerRadius: SettingsMetrics.sidebarRowCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SettingsSidebarNavigationRow(
            systemImage: section.systemImage,
            title: section.title,
            isSelected: isSelected,
            action: action
        )
    }
}
