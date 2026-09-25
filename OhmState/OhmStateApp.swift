import SwiftUI
import os

private let appLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OhmState", category: "app")

@main
struct OhmStateApp: App {
    nonisolated static let mainWindowID = "main"
    nonisolated static let showInMenuBarKey = "showInMenuBar"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = HeadphoneImpedanceMonitor()
    @State private var loginItem = LoginItemModel()
    @AppStorage(OhmStateApp.showInMenuBarKey) private var showInMenuBar = false

    var body: some Scene {
        Window("OhmState", id: Self.mainWindowID) {
            MainWindowView(reading: monitor.reading, showInMenuBar: $showInMenuBar, loginItem: loginItem)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra(isInserted: $showInMenuBar) {
            StatusMenuContent(reading: monitor.reading)
        } label: {
            let state = monitor.state
            Image(nsImage: HeadphoneStateIcon.menuBarImage(for: state))
                .accessibilityLabel("Headphone output: \(state.title)")
            if let text = state.menuBarText {
                Text(text)
            }
        }
        .menuBarExtraStyle(.menu)
        // Handled here rather than in the window, because the item can also be removed while
        // the window is closed (e.g. ⌘-dragged out of the menu bar), which flips this binding.
        .onChange(of: showInMenuBar) { _, shown in
            if !shown { menuBarItemRemoved() }
        }
    }

    private func menuBarItemRemoved() {
        // Launching at login without a menu-bar item would just pop the window up, so the
        // login item has to go. If macOS refuses, put the menu-bar item back rather than
        // leave the two settings disagreeing; the error shows in the window.
        if loginItem.isEnabled && !loginItem.setEnabled(false) {
            appLog.error("Couldn't remove login item; restoring the menu bar item")
            showInMenuBar = true
            return
        }
        // With the window closed there's nothing left on screen, so quit instead of
        // running invisibly.
        if !AppDelegate.isMainWindowVisible {
            appLog.info("Menu bar item removed while the window is closed; quitting")
            NSApplication.shared.terminate(nil)
        }
    }
}

/// Switches between a normal Dock app (window open) and a menu-bar-only accessory app
/// (window closed, menu-bar item enabled). With the menu-bar item disabled, closing the
/// window quits the app. A login-item launch starts in the menu bar without the window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = appLog
    private var isQuitting = false

    private var showInMenuBar: Bool {
        UserDefaults.standard.bool(forKey: OhmStateApp.showInMenuBarKey)
    }

    /// Quitting is decided in `windowWillClose`, not by SwiftUI's single-window default.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        center.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)

        // Only honor a login launch when there's a menu-bar item to fall back to.
        if showInMenuBar && LoginItem.launchedAtLogin() {
            log.info("Launched at login; starting in menu bar only")
            // SwiftUI has already created the window by now; closing it in this same run-loop
            // turn keeps it from ever being drawn. windowWillClose switches to accessory mode.
            NSApplication.shared.windows.first { Self.isMainWindow($0) }?.close()
        }
    }

    @objc private func windowDidBecomeKey(_ note: Notification) {
        guard Self.isMainWindow(note.object), NSApplication.shared.activationPolicy() != .regular else { return }
        log.info("Main window shown; showing Dock icon")
        NSApplication.shared.setActivationPolicy(.regular)
    }

    @objc private func windowWillClose(_ note: Notification) {
        // Termination closes the window again; ignore that second notification.
        guard Self.isMainWindow(note.object), !isQuitting else { return }
        if showInMenuBar {
            log.info("Main window closed; continuing in menu bar only")
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            log.info("Main window closed; quitting")
            isQuitting = true
            NSApplication.shared.terminate(nil)
        }
    }

    static var isMainWindowVisible: Bool {
        NSApplication.shared.windows.contains { isMainWindow($0) && $0.isVisible }
    }

    private static func isMainWindow(_ object: Any?) -> Bool {
        // SwiftUI uses the Window scene id as the NSWindow identifier (observed: "main").
        (object as? NSWindow)?.identifier?.rawValue.hasPrefix(OhmStateApp.mainWindowID) == true
    }
}
