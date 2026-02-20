
import Foundation
import SwiftUI

enum MenuBarTextMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case exactTime = "Exact Time"
    case hidden = "Icon Only"
    var id: Self { self }

    // Localized display name for UI
    var localized: LocalizedStringKey {
        return LocalizedStringKey(self.rawValue)
    }
}
