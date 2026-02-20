
import Foundation
import ServiceManagement

struct StartupManager {
    static func toggleLaunchAtLogin(isEnabled: Bool) {
        do {
            let service = SMAppService()
            
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // SMAppService registration failure is non-critical
        }
    }
}
