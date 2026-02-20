// MARK: - Notification+Names.swift
// Centralized notification names used across the application.

import Foundation

extension Notification.Name {
    /// Posted when prayer times have been recalculated.
    static let prayerTimesUpdated = Notification.Name("prayerTimesUpdated")
    
    /// Posted when the popover window opens.
    static let popoverDidOpen = Notification.Name("com.sajda.popoverDidOpen")
    
    /// Posted when the popover window closes.
    static let popoverDidClose = Notification.Name("com.sajda.popoverDidClose")
}
