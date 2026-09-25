import AppKit
import Observation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp`, the sandbox-friendly "Open at Login" API.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else if status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    /// True when this process was started by the login-items mechanism rather than the user.
    /// LaunchServices tags the "open application" Apple Event it sends at login.
    @MainActor
    static func launchedAtLogin() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

/// Observable login-item state shared by the app (which enforces the menu-bar coupling)
/// and the main window (which shows the toggle and any error).
@MainActor
@Observable
final class LoginItemModel {
    private(set) var status = LoginItem.status
    private(set) var error: String?

    /// Registered, including when macOS is still waiting for the user's approval.
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }

    /// Returns false, and records a user-facing error, if macOS refused the change.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        defer { refresh() }
        do {
            try LoginItem.setEnabled(enabled)
            error = nil
            return true
        } catch {
            self.error = "Couldn't change Open at login: \(error.localizedDescription)"
            return false
        }
    }

    /// Re-reads the status; the user can change it in System Settings while we run.
    func refresh() {
        status = LoginItem.status
    }
}
