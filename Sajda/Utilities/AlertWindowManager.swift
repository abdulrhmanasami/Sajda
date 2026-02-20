
import SwiftUI

class AlertWindowManager {
    static let shared = AlertWindowManager()
    private var window: NSWindow?

    private init() {}

    func showAlert() {
        guard window == nil else { return }

        let alertView = PrayerTimerAlertView {
            self.closeAlert()
        }
        
        let hostingController = NSHostingController(rootView: alertView)
        let newWindow = NSWindow(contentViewController: hostingController)
        
        
        // Borderless panel style
        newWindow.styleMask = .borderless
        
        // Float above other windows
        newWindow.level = .floating
        
        // Transparent background for blur effect
        newWindow.isOpaque = false
        newWindow.backgroundColor = NSColor.clear
        
        
        newWindow.center()
        
        self.window = newWindow
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAlert() {
        window?.close()
        window = nil
    }
}
