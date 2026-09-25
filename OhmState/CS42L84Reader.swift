import Foundation
import IOKit

/// A snapshot of the properties published by Apple's CS42L84 headphone-codec driver.
///
/// Values are copied verbatim from IORegistry; interpretation happens in `HeadphoneOutputState`.
struct CS42L84Reading: Equatable, Sendable {
    /// Whether an `AppleCS42L84Audio` service exists in IORegistry.
    var serviceFound: Bool
    /// The raw `DCIDMode` value, if it was present and a string.
    var dcidMode: String?
    /// Why `dcidMode` is nil even though the service was found.
    var dcidModeProblem: String?
    /// Secondary properties, shown only in diagnostics. Semantics are undocumented.
    var supportsDCID: Bool?
    var headphoneDetect: Bool?
    var detectConfidence: String?

    static let notFound = CS42L84Reading(serviceFound: false)
}

/// Anything that can produce a reading; lets tests substitute a fake for the IOKit reader.
protocol CS42L84ReadingSource: AnyObject {
    func read() -> CS42L84Reading
}

/// Reads `DCIDMode` directly from the `AppleCS42L84Audio` IORegistry entry.
///
/// All IOKit code lives here so the rest of the app never touches `io_object_t` handles.
/// Not thread-safe; use from a single actor (the main actor in this app).
final class CS42L84Reader: CS42L84ReadingSource {
    static let serviceClass = "AppleCS42L84Audio"

    /// Cached registry entry. We hold one reference and release it in `deinit` or when
    /// the entry is detached from the registry (e.g. the driver is restarted).
    private var service: io_service_t = IO_OBJECT_NULL

    deinit {
        releaseService()
    }

    func read() -> CS42L84Reading {
        guard let service = currentService() else { return .notFound }

        var reading = CS42L84Reading(serviceFound: true)
        switch property("DCIDMode", of: service) {
        case let value as String:
            reading.dcidMode = value
        case nil:
            reading.dcidModeProblem = "DCIDMode property is missing"
        case let other?:
            reading.dcidModeProblem = "DCIDMode has unexpected type \(CFCopyTypeIDDescription(CFGetTypeID(other)) as String)"
        }
        reading.supportsDCID = property("Supports DCID", of: service) as? Bool
        reading.headphoneDetect = property("HPDetect", of: service) as? Bool
        reading.detectConfidence = property("DetectConfidence", of: service) as? String
        return reading
    }

    /// Returns the cached service, looking it up again if we don't have one or it went away.
    private func currentService() -> io_service_t? {
        // A terminated service is detached from the service plane but the handle stays valid,
        // so an inactive entry would otherwise keep returning stale properties.
        if service != IO_OBJECT_NULL, IORegistryEntryInPlane(service, kIOServicePlane) == 0 {
            releaseService()
        }
        if service == IO_OBJECT_NULL {
            // IOServiceGetMatchingService consumes the matching dictionary and returns a +1
            // reference (or IO_OBJECT_NULL), which we own until releaseService().
            guard let matching = IOServiceMatching(Self.serviceClass) else { return nil }
            service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        }
        return service == IO_OBJECT_NULL ? nil : service
    }

    private func releaseService() {
        if service != IO_OBJECT_NULL {
            IOObjectRelease(service)
            service = IO_OBJECT_NULL
        }
    }

    /// Copies a single property (a +1 CF object, balanced by takeRetainedValue).
    private func property(_ key: String, of entry: io_registry_entry_t) -> CFTypeRef? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
