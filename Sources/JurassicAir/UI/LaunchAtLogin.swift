import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService for registering the main app as a login item.
/// Requires macOS 13+ and a proper .app bundle (not `swift run` from terminal).
enum LaunchAtLogin {
    /// True if we're running from a proper .app bundle. We don't gate on
    /// `SMAppService.mainApp.status != .notFound` because `.notFound` is a
    /// normal state for a freshly built bundle that hasn't been registered yet —
    /// calling register() itself triggers LaunchServices to index the bundle.
    /// `swift run` binaries have no Info.plist and therefore no bundle id, so
    /// this correctly excludes the dev-loop case.
    static var isAvailable: Bool {
        if #available(macOS 13.0, *) {
            return Bundle.main.bundleIdentifier != nil
        }
        return false
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Returns true on success, false otherwise (e.g. user has not approved yet,
    /// or app isn't running from a bundle). Errors are logged.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LaunchAtLogin toggle failed: \(error)")
            return false
        }
    }
}
