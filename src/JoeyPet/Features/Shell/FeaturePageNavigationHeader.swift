import SwiftUI

/// Page-level back / breadcrumb header. Lives inside feature content—not in the global toolbar.
struct FeaturePageNavigationHeader: View {
    let parentTitle: String
    let pageTitle: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onBack) {
                Label(parentTitle, systemImage: "chevron.backward")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text(pageTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
