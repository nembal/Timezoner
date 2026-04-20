import Foundation
import ServiceManagement

public enum LaunchAtLogin {
    public enum Result {
        case ok
        case failed(String)
    }

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    public static func set(_ enabled: Bool) -> Result {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return .ok
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public static func reconcile(desired: Bool) -> Result {
        let current = isEnabled
        guard current != desired else { return .ok }
        return set(desired)
    }
}
