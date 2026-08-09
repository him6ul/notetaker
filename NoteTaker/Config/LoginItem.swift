import Foundation
import ServiceManagement

/// Wraps macOS "Open at Login" registration for the app itself (SMAppService, macOS 13+).
/// No helper bundle or extra entitlement is needed to register the main app.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Registers or unregisters the app as a login item. Idempotent; logs and returns false on failure.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
            return true
        } catch {
            NSLog("NoteTaker: login-item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
            return false
        }
    }
}
