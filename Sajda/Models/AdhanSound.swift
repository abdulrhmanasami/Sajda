
import Foundation

enum AdhanSound: String, CaseIterable, Identifiable {
    case none = "None"
    case defaultBeep = "Default Beep"
    case custom = "Custom Sound"
    var id: Self { self }
}
