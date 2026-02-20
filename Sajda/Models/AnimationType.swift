
import Foundation
import SwiftUI

enum AnimationType: String, CaseIterable, Identifiable {
    case none = "None"
    case fade = "Fade"
    case slide = "Slide"
    
    var id: Self { self }
    
    // Localized display name for UI
    var localized: LocalizedStringKey {
        return LocalizedStringKey(self.rawValue)
    }
}
