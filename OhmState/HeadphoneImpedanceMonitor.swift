import Foundation
import Observation
import os

/// Keeps `reading` current and publishes changes to SwiftUI.
///
/// The driver sends no IOKit notification when `DCIDMode` changes, so updates are driven by
/// CoreAudio device-list changes (plug/unplug). After each change the property is re-read
/// several times a second for a few seconds, because the driver settles on a mode ~1.3 s
/// after the jack reports a connection. A slow poll is kept as a safety net.
@MainActor
@Observable
final class HeadphoneImpedanceMonitor {
    private(set) var reading: CS42L84Reading
    private(set) var state: HeadphoneOutputState

    @ObservationIgnored private let reader: any CS42L84ReadingSource
    @ObservationIgnored private var deviceObserver: AudioDeviceListObserver?
    @ObservationIgnored private var burstTask: Task<Void, Never>?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OhmState", category: "monitor")

    private static let burstInterval = Duration.milliseconds(250)
    private static let burstLength = Duration.seconds(5)
    private static let fallbackPollInterval = Duration.seconds(1)

    /// - Parameters:
    ///   - reader: the property source; tests pass a fake.
    ///   - safetyPollInterval: how often to re-read without a device-change event.
    init(reader: any CS42L84ReadingSource = CS42L84Reader(), safetyPollInterval: Duration = .seconds(30)) {
        self.reader = reader
        let initial = reader.read()
        reading = initial
        state = HeadphoneOutputState(initial)
        log.info("Initial state: \(self.state.diagnosticName, privacy: .public), raw: \(initial.dcidMode ?? "nil", privacy: .public)")

        deviceObserver = AudioDeviceListObserver { [weak self] in self?.startBurst() }
        if deviceObserver == nil {
            log.error("CoreAudio listener unavailable; falling back to 1 s polling")
        }
        // Runs even if the service is missing now: it may be mid-restart at launch, and the
        // reader looks it up again on every read until it appears.
        startPolling(every: deviceObserver == nil ? Self.fallbackPollInterval : safetyPollInterval)
    }

    func refresh() {
        let new = reader.read()
        // Only assign on change so SwiftUI isn't invalidated needlessly.
        guard new != reading else { return }
        reading = new
        state = HeadphoneOutputState(new)
        log.info("State changed: \(self.state.diagnosticName, privacy: .public), raw: \(new.dcidMode ?? "nil", privacy: .public)")
    }

    /// Re-reads quickly for a few seconds after a device change so the settled mode shows promptly.
    private func startBurst() {
        log.debug("Audio device list changed; re-reading")
        burstTask?.cancel()
        burstTask = Task { [weak self] in
            let clock = ContinuousClock()
            let end = clock.now + Self.burstLength
            while !Task.isCancelled {
                guard let self else { return }
                self.refresh()
                guard clock.now < end else { break }
                try? await Task.sleep(for: Self.burstInterval)
            }
        }
    }

    private func startPolling(every interval: Duration) {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval, tolerance: interval / 4)
                guard let self else { return }  // Monitor deallocated; stop polling.
                self.refresh()
            }
        }
    }
}
