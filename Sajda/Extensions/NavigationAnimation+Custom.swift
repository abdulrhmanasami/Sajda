// MARK: - NavigationAnimation+Custom.swift

import NavigationStack
import SwiftUI

extension NavigationAnimation {
    /// Lightweight cross-fade with subtle scale effect for depth.
    static let sajdaCrossfade: NavigationAnimation = NavigationAnimation(
        animation: .easeInOut(duration: 0.25),
        defaultViewTransition: .opacity.combined(with: .scale(scale: 0.97)),
        alternativeViewTransition: .opacity.combined(with: .scale(scale: 1.0))
    )
}
