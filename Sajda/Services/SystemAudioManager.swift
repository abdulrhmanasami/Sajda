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
    private var savedDeviceUID: String?
    
    private init() {}
    
    // MARK: - Audio Output Device Model
    
    struct AudioOutputDevice: Identifiable, Hashable {
        let id: String       // Device UID (unique identifier)
        let name: String     // Human-readable name
        let deviceID: AudioDeviceID
    }
    
    // MARK: - Device Enumeration
    
    /// Returns all available audio output devices.
    func getOutputDevices() -> [AudioOutputDevice] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize
        ) == noErr else { return [] }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &propertySize, &deviceIDs
        ) == noErr else { return [] }
        
        var outputDevices: [AudioOutputDevice] = []
        
        for deviceID in deviceIDs {
            // Check if device has output channels
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr else { continue }
            
            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(streamSize))
            defer { bufferListPointer.deallocate() }
            
            guard AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &streamSize, bufferListPointer) == noErr else { continue }
            
            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let outputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard outputChannels > 0 else { continue }
            
            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameRef: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef)
            let name = nameRef as String
            
            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidRef: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uidRef)
            let uid = uidRef as String
            
            guard !uid.isEmpty else { continue }
            outputDevices.append(AudioOutputDevice(id: uid, name: name, deviceID: deviceID))
        }
        
        return outputDevices
    }
    
    /// Resolves a device UID to its AudioDeviceID. Returns default output if not found.
    private func resolveDeviceID(forUID uid: String?) -> AudioDeviceID {
        if let uid = uid, !uid.isEmpty {
            let devices = getOutputDevices()
            if let device = devices.first(where: { $0.id == uid }) {
                return device.deviceID
            }
        }
        // Fallback to system default
        return getDefaultOutputDeviceID()
    }
    
    private func getDefaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: deviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }
    
    // MARK: - Public API
    
    /// Saves the current volume and mute state for later restoration.
    func saveState(deviceUID: String? = nil) {
        savedDeviceUID = deviceUID
        savedVolume = getVolume(deviceUID: deviceUID)
        savedMuteState = isMuted(deviceUID: deviceUID)
    }
    
    /// Restores the previously saved volume and mute state.
    func restoreState() {
        if let volume = savedVolume {
            setVolume(volume, deviceUID: savedDeviceUID)
        }
        if let muted = savedMuteState {
            setMuted(muted, deviceUID: savedDeviceUID)
        }
        savedVolume = nil
        savedMuteState = nil
        savedDeviceUID = nil
    }
    
    /// Overrides volume: unmutes and sets to the specified level on the given device.
    func overrideVolume(to level: Float, deviceUID: String? = nil) {
        setMuted(false, deviceUID: deviceUID)
        setVolume(min(max(level, 0.0), 1.0), deviceUID: deviceUID)
    }
    
    // MARK: - CoreAudio Volume Control
    
    func getVolume(deviceUID: String? = nil) -> Float {
        let deviceID = resolveDeviceID(forUID: deviceUID)
        
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout.size(ofValue: volume))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let volStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return volStatus == noErr ? volume : 0.5
    }
    
    func setVolume(_ volume: Float, deviceUID: String? = nil) {
        let deviceID = resolveDeviceID(forUID: deviceUID)
        
        var newVolume = volume
        var size = UInt32(MemoryLayout.size(ofValue: newVolume))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newVolume)
    }
    
    func isMuted(deviceUID: String? = nil) -> Bool {
        let deviceID = resolveDeviceID(forUID: deviceUID)
        
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: muted))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let muteStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        return muteStatus == noErr ? (muted != 0) : false
    }
    
    func setMuted(_ muted: Bool, deviceUID: String? = nil) {
        let deviceID = resolveDeviceID(forUID: deviceUID)
        
        var muteValue: UInt32 = muted ? 1 : 0
        var size = UInt32(MemoryLayout.size(ofValue: muteValue))
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &muteValue)
    }
}
