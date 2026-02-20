// MARK: - LanguageManager.swift
// Manages runtime language switching with Bundle swizzling.

import SwiftUI

/// Single source of truth for the active language.
class LanguageManager: ObservableObject {
    @AppStorage("selectedLanguage") var language: String = "en" {
        didSet {
            Bundle.setLanguage(language)
            objectWillChange.send()
        }
    }
}

/// Wrapper view that applies locale, layout direction, and forces re-render on language change.
struct LanguageManagerView<Content: View>: View {
    @StateObject var manager: LanguageManager
    let content: Content

    init(manager: LanguageManager, @ViewBuilder content: () -> Content) {
        _manager = StateObject(wrappedValue: manager)
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(manager)
            .environment(\.locale, Locale(identifier: manager.language))
            .environment(\.layoutDirection, manager.language == "ar" ? .rightToLeft : .leftToRight)
            .id(manager.language)
    }
}

// MARK: - Bundle Language Swizzling (thread-safe)

private let bundleLock = NSLock()
private var bundleKey: UInt8 = 0

class AnyLanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        bundleLock.lock()
        defer { bundleLock.unlock() }
        guard let path = objc_getAssociatedObject(self, &bundleKey) as? String,
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        bundleLock.lock()
        defer { bundleLock.unlock() }
        object_setClass(Bundle.main, AnyLanguageBundle.self)
        let value = language == "en" ? nil : Bundle.main.path(forResource: language, ofType: "lproj")
        objc_setAssociatedObject(Bundle.main, &bundleKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
