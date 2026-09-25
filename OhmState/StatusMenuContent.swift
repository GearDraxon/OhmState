import SwiftUI

/// The native menu shown when the menu-bar item is clicked.
///
/// Status lines are plain `Text`, which a `.menu`-style MenuBarExtra renders as
/// non-interactive items; the buttons get standard menu highlighting.
struct StatusMenuContent: View {
    let reading: CS42L84Reading

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let state = HeadphoneOutputState(reading)

        Section("Headphone Jack") {
            Text(state.title)
            ForEach(state.details, id: \.self) { Text($0) }
            if let driverMode = state.driverModeLine { Text(driverMode) }
        }

        Divider()

        Button("Open OhmState…") {
            openWindow(id: OhmStateApp.mainWindowID)
            NSApplication.shared.activate()
        }

        Divider()

        Button("Quit OhmState") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
