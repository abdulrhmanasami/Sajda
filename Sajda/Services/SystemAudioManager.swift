// MARK: - SystemAudioManager.swift
// Manages system audio volume via CoreAudio.
// Provides save/restore pattern for temporary volume overrides during Adhan playback.

import Foundation
import CoreAudio
import AudioToolbox

final class SystemAudioManager {
    static let shared = SystemAudioManager()
    
    private var savedVolume: Float?
    private var savedMuteState: Bool?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Saves the current volume and mute state for later restoration.
    func saveState() {
        savedVolume = getVolume()
        savedMuteState = isMuted()
    }
    
    /// Restores the previously saved volume and mute state.
    func restoreState() {
        if let volume = savedVolume {
            setVolume(volume)
        }
        if let muted = savedMuteState {
            setMuted(muted)
        }
        savedVolume = nil
        savedMuteState = nil
    }
    
    /// Overrides volume: unmutes and sets to the specified level.
    func overrideVolume(to level: Float) {
        setMuted(false)
        setVolume(min(max(level, 0.0), 1.0))
    }
    
    // MARK: - CoreAudio Volume Control
    
    func getVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultOutputDeviceID
        )
        guard status == noErr else { return 0.5 }
        
        var volume: Float32 = 0.5
        size = UInt32(MemoryLayout.size(ofValue: volume))
        
        address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let volStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &address, 0, nil, &size, &volume)
        return volStatus == noErr ? volume : 0.5
    }
    
    func setVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultOutputDeviceID
        )
        guard status == noErr else { return }
        
        var newVolume = volume
        size = UInt32(MemoryLayout.size(ofValue: newVolume))
        
        address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectSetPropertyData(defaultOutputDeviceID, &address, 0, nil, size, &newVolume)
    }
    
    func isMuted() -> Bool {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultOutputDeviceID
        )
        guard status == noErr else { return false }
        
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout.size(ofValue: muted))
        
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let muteStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &address, 0, nil, &size, &muted)
        return muteStatus == noErr ? (muted != 0) : false
    }
    
    func setMuted(_ muted: Bool) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &defaultOutputDeviceID
        )
        guard status == noErr else { return }
        
        var muteValue: UInt32 = muted ? 1 : 0
        size = UInt32(MemoryLayout.size(ofValue: muteValue))
        
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectSetPropertyData(defaultOutputDeviceID, &address, 0, nil, size, &muteValue)
    }
}
