import SwiftUI

/// The output headline and driver mode shown in the main window.
struct StatusSummaryView: View {
    let state: HeadphoneOutputState
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Headphone Jack")
                .font(large ? .subheadline : .caption)
                .foregroundStyle(.secondary)
            Text(state.title)
                .font(large ? .title.weight(.semibold) : .title3.weight(.semibold))
            ForEach(Array(state.details.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? .body : .callout)
                    .foregroundStyle(index == 0 ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let driverMode = state.driverModeLine {
                Text(driverMode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Collapsible raw readout with a Copy button, for bug reports.
struct DiagnosticsSection: View {
    let reading: CS42L84Reading

    @State private var isExpanded = false
    @State private var copied = false

    var body: some View {
        DisclosureGroup("Diagnostics", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.vertical) {
                    Text(Diagnostics.report(reading: reading, state: HeadphoneOutputState(reading)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160)
                Text("OhmState reports the output mode macOS selected for the connected load. It does not measure impedance.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(copied ? "Copied" : "Copy Diagnostics", action: copy)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        }
        .font(.callout)
    }

    private func copy() {
        let report = Diagnostics.report(reading: reading, state: HeadphoneOutputState(reading), date: .now)
        Diagnostics.copyToPasteboard(report)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
