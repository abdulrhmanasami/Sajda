// MARK: - AdhanAlertService.swift
// Persistent Adhan alert engine.
// Handles: sleep prevention, volume override, full playback, global key dismiss.

import Foundation
import AppKit
import IOKit.pwr_mgt

final class AdhanAlertService: NSObject, NSSoundDelegate {
    static let shared = AdhanAlertService()
    
    // MARK: - State
    
    private var currentSound: NSSound?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var sleepAssertionID: IOPMAssertionID = 0
    private var hasSleepAssertion = false
    private var alertWindow: NSWindow?
    private var sleepPreventionTimer: Timer?
    private var didOverrideVolume = false
    private var activeSecurityScopedURL: URL?
    
    /// Whether persistent Adhan is currently playing.
    private(set) var isPlaying = false
    
    private override init() { super.init() }
    
    // MARK: - Public API
    
    /// Sets the security-scoped URL to release after playback.
    func setSecurityScopedURL(_ url: URL?) {
        activeSecurityScopedURL = url
    }
    
    /// Plays the Adhan with full persistence: volume override, sleep prevention, key dismiss.
    func playAdhan(prayerName: String, soundURL: URL?, overrideVolume: Float, deviceUID: String? = nil) {
        guard !isPlaying else { return }
        isPlaying = true
        
        // 1. Prevent system sleep
        createSleepAssertion()
        
        // 2. Override volume on the target device (skip for defaultBeep where volume=0.0)
        if overrideVolume > 0.0 {
            SystemAudioManager.shared.saveState(deviceUID: deviceUID)
            SystemAudioManager.shared.overrideVolume(to: overrideVolume, deviceUID: deviceUID)
            didOverrideVolume = true
        } else {
            didOverrideVolume = false
        }
        
        // 3. Play sound
        if let url = soundURL, FileManager.default.fileExists(atPath: url.path) {
            currentSound = NSSound(contentsOf: url, byReference: false)
        } else {
            // Fallback: system alert sound played once
            currentSound = NSSound(named: .init("Funk"))
        }
        currentSound?.delegate = self
        
        // Route to specific output device
        if let uid = deviceUID, !uid.isEmpty {
            currentSound?.playbackDeviceIdentifier = uid
        }
        
        currentSound?.play()
        
        // 4. Show Adhan alert window
        showAdhanAlert(prayerName: prayerName)
        
        // 5. Install global keyboard monitor
        installKeyboardMonitor()
    }
    
    /// Stops the Adhan and restores system state.
    func dismiss() {
        guard isPlaying else { return }
        
        // Stop sound
        currentSound?.stop()
        currentSound = nil
        
        // PF-6: Restore volume only if it was actually overridden
        if didOverrideVolume {
            SystemAudioManager.shared.restoreState()
            didOverrideVolume = false
        }
        
        // Remove keyboard monitor
        removeKeyboardMonitor()
        
        // Release sleep assertion
        releaseSleepAssertion()
        
        // Close alert window
        closeAdhanAlert()
        
        // PF-1: Release security-scoped resource
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedURL = nil
        
        isPlaying = false
    }
    
    /// Schedules sleep prevention for upcoming prayer times.
    /// Call this after prayer times are recalculated.
    func scheduleSleepPrevention(for prayerTimes: [String: Date]) {
        sleepPreventionTimer?.invalidate()
        
        let now = Date()
        // Find the next upcoming prayer within 5 minutes
        guard let nextPrayer = prayerTimes.values
            .filter({ $0 > now })
            .min() else { return }
        
        let leadTime: TimeInterval = 5 * 60 // 5 minutes before prayer
        let preventionTime = nextPrayer.addingTimeInterval(-leadTime)
        
        guard preventionTime > now else {
            // Less than 5 min away — prevent sleep now
            createSleepAssertion()
            return
        }
        
        sleepPreventionTimer = Timer.scheduledTimer(withTimeInterval: preventionTime.timeIntervalSinceNow, repeats: false) { [weak self] _ in
            self?.createSleepAssertion()
        }
    }
    
    // MARK: - NSSoundDelegate
    
    func sound(_ sound: NSSound, didFinishPlaying aBool: Bool) {
        // Sound finished naturally — clean up
        DispatchQueue.main.async { [weak self] in
            self?.dismiss()
        }
    }
    
    // MARK: - Sleep Prevention (IOPMAssertionCreate)
    
    private func createSleepAssertion() {
        guard !hasSleepAssertion else { return }
        
        let reason = "Sajda: Adhan playback — preventing system sleep" as CFString
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &sleepAssertionID
        )
        hasSleepAssertion = (status == kIOReturnSuccess)
    }
    
    private func releaseSleepAssertion() {
        guard hasSleepAssertion else { return }
        IOPMAssertionRelease(sleepAssertionID)
        hasSleepAssertion = false
    }
    
    // MARK: - Global Keyboard Monitor
    
    private func installKeyboardMonitor() {
        // H-006: Check Accessibility permission for global monitoring
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        
        if trusted {
            // Global monitor: catches key events when app is NOT focused
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                DispatchQueue.main.async { self?.dismiss() }
            }
        }
        
        // Local monitor: catches key events when app IS focused (always works)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DispatchQueue.main.async { self?.dismiss() }
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    // MARK: - Adhan Alert Window
    
    private func showAdhanAlert(prayerName: String) {
        guard alertWindow == nil else { return }
        
        let localizedName = NSLocalizedString(prayerName, comment: "")
        let alertView = AdhanAlertView(prayerName: localizedName) { [weak self] in
            self?.dismiss()
        }
        
        let hostingController = NSHostingController(rootView: alertView)
        let window = NSWindow(contentViewController: hostingController)
        
        window.styleMask = .borderless
        window.level = .screenSaver // Above everything
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.center()
        
        self.alertWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeAdhanAlert() {
        alertWindow?.close()
        alertWindow = nil
    }
}

// MARK: - Adhan Alert View (Inline)

import SwiftUI

struct AdhanAlertView: View {
    let prayerName: String
    let dismissAction: () -> Void
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Pulsing mosque icon
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.green)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulseScale = 1.15
                        }
                    }
                
                VStack(spacing: 4) {
                    Text(prayerName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(LocalizedStringKey("Adhan is playing..."))
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text(LocalizedStringKey("Press any key to dismiss"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Button(action: dismissAction) {
                    Text(LocalizedStringKey("Dismiss"))
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            }
            .padding(40)
        }
        .frame(width: 450, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30)
        .scaleEffect(isAnimating ? 1.0 : 0.9)
        .opacity(isAnimating ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}
