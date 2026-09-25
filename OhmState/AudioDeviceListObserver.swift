import CoreAudio
import Foundation

/// Calls a handler when the system's audio device list changes.
///
/// On Macs with the adaptive headphone jack, CoreAudio adds an "External Headphones" device
/// within ~60 ms of a plug-in and removes it on unplug. The CS42L84 driver itself sends no
/// IOKit notification, so this is the cheapest reliable signal to re-read `DCIDMode`.
final class AudioDeviceListObserver {
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private let listener: AudioObjectPropertyListenerBlock

    /// Returns nil if CoreAudio refuses the listener; the caller should fall back to polling.
    init?(onChange: @escaping @MainActor () -> Void) {
        listener = { _, _ in
            MainActor.assumeIsolated { onChange() }
        }
        // Delivered on the main queue, which is what makes assumeIsolated above valid.
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        guard status == noErr else { return nil }
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }
}
