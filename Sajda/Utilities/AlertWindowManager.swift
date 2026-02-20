
import SwiftUI

class AlertWindowManager {
    static let shared = AlertWindowManager()
    private var window: NSWindow?
    private var autoDismissTimer: Timer?

    private init() {}

    /// Shows the prayer timer alert. Auto-dismisses after `autoDismissAfter` seconds (default: 600s = 10 min).
    func showAlert(autoDismissAfter: TimeInterval = 600) {
        guard window == nil else { return }

        let alertView = PrayerTimerAlertView { [weak self] in
            self?.closeAlert()
        }
        
        let hostingController = NSHostingController(rootView: alertView)
        let newWindow = NSWindow(contentViewController: hostingController)
        
        newWindow.styleMask = .borderless
        newWindow.level = .floating
        newWindow.isOpaque = false
        newWindow.backgroundColor = NSColor.clear
        newWindow.center()
        
        self.window = newWindow
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Auto-dismiss after timeout
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { [weak self] _ in
            self?.closeAlert()
        }
    }

    func closeAlert() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        window?.close()
        window = nil
    }
}
