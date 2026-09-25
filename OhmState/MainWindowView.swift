import ServiceManagement
import SwiftUI

/// The app's primary window: current mode, diagnostics, and the menu-bar option.
struct MainWindowView: View {
    let reading: CS42L84Reading
    @Binding var showInMenuBar: Bool
    let loginItem: LoginItemModel

    var body: some View {
        let state = HeadphoneOutputState(reading)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                HeadphoneStateIcon(state: state)
                    .foregroundStyle(
                        state == .highImpedance ? AnyShapeStyle(.orange) :
                        state.isActiveMode ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
                    )
                    .accessibilityHidden(true)
                StatusSummaryView(state: state, large: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show in menu bar", isOn: $showInMenuBar)
                Text("Keeps OhmState running after this window closes. Enables Open at login.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showInMenuBar {
                    Toggle("Open at login", isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    ))
                        .padding(.top, 4)
                        .padding(.leading, 18)
                    if loginItem.status == .requiresApproval {
                        HStack(spacing: 6) {
                            Text("Needs approval in Login Items settings.")
                            Button("Open Settings") { SMAppService.openSystemSettingsLoginItems() }
                                .buttonStyle(.link)
                        }
                        .font(.caption)
                        .padding(.leading, 18)
                    }
                    if let loginError = loginItem.error {
                        Text(loginError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 18)
                    }
                }
            }

            DiagnosticsSection(reading: reading)
        }
        .padding(20)
        .frame(width: 380)
        // The user can also change this in System Settings while we're open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }
}

#Preview("High Impedance") {
    MainWindowView(reading: CS42L84Reading(serviceFound: true, dcidMode: "High Impedance"), showInMenuBar: .constant(false), loginItem: LoginItemModel())
}

#Preview("Unplugged") {
    MainWindowView(reading: CS42L84Reading(serviceFound: true, dcidMode: "Unplugged"), showInMenuBar: .constant(true), loginItem: LoginItemModel())
}

#Preview("Unsupported") {
    MainWindowView(reading: .notFound, showInMenuBar: .constant(false), loginItem: LoginItemModel())
}
