
import Foundation
import ServiceManagement

struct StartupManager {
    static func toggleLaunchAtLogin(isEnabled: Bool) {
        do {
            let service = SMAppService.mainApp
            
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("[Sajda] Launch at login toggle failed: \(error.localizedDescription)")
        }
    }
}
