import Foundation

/// The app's interpretation of a `CS42L84Reading`.
enum HeadphoneOutputState: Equatable {
    /// No `AppleCS42L84Audio` service: this Mac lacks the adaptive headphone output.
    case unsupported
    /// The service exists but `DCIDMode` could not be read.
    case unreadable(reason: String)
    case unplugged
    /// The jack reports a connection but the driver hasn't chosen a mode yet (~1.3 s after plug-in).
    case detecting
    case lowImpedance
    case highImpedance
    /// Advertised by the driver's IOReport legend but never observed; string match is a guess.
    case oneVoltRMS(raw: String)
    /// Advertised by the driver's IOReport legend but never observed; string match is a guess.
    case highCapacitance(raw: String)
    /// A `DCIDMode` string this version of the app doesn't recognize.
    case unknown(raw: String)

    init(_ reading: CS42L84Reading) {
        guard reading.serviceFound else { self = .unsupported; return }
        guard let raw = reading.dcidMode else {
            self = .unreadable(reason: reading.dcidModeProblem ?? "Unknown error")
            return
        }
        // Low/High carry voltage claims, so only the exact strings verified on hardware map to
        // them; a variant such as "LowImpedance" falls through to .unknown with its raw value.
        // Loose matching is limited to the unverified modes, which show the raw string anyway.
        switch raw {
        case "Unplugged": self = reading.headphoneDetect == true ? .detecting : .unplugged
        case "Low Impedance": self = .lowImpedance
        case "High Impedance": self = .highImpedance
        default:
            let key = raw.lowercased().filter { $0.isLetter || $0.isNumber }
            switch key {
            case "1vrms", "onevoltrms": self = .oneVoltRMS(raw: raw)
            case "hicapacitance", "highcapacitance": self = .highCapacitance(raw: raw)
            default: self = .unknown(raw: raw)
            }
        }
    }
}

// MARK: - Presentation

extension HeadphoneOutputState {
    /// Short text shown next to the menu-bar icon; nil for icon only. Low and High have no
    /// text: the icon itself carries a bolt in high-voltage mode.
    var menuBarText: String? {
        switch self {
        case .oneVoltRMS: "1V"
        case .highCapacitance: "HiCap"
        case .unknown: "?"
        case .detecting: "…"
        case .unsupported, .unreadable, .unplugged, .lowImpedance, .highImpedance: nil
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .unsupported, .unreadable: "headphones.slash"
        default: "headphones"
        }
    }

    var title: String {
        switch self {
        case .unsupported: "Not Available"
        case .unreadable: "Mode Unavailable"
        case .unplugged: "No headphones connected"
        case .detecting: "Detecting…"
        case .lowImpedance: "Standard output"
        case .highImpedance: "High-voltage output"
        case .oneVoltRMS: "1 V RMS Mode"
        case .highCapacitance: "High Capacitance"
        case .unknown: "Unrecognized Mode"
        }
    }

    /// Secondary lines under the title, most important first.
    var details: [String] {
        switch self {
        case .unsupported:
            ["Adaptive headphone output not detected on this Mac"]
        case .unreadable(let reason):
            ["The headphone audio driver was found, but its output mode could not be read.", reason]
        case .unplugged:
            ["Plug in headphones to see which output mode macOS selects."]
        case .detecting:
            ["Headphones connected. Waiting for macOS to select an output mode."]
        case .lowImpedance:
            ["Up to 1.25 V RMS"]
        case .highImpedance:
            ["Up to 3 V RMS"]
        case .oneVoltRMS, .highCapacitance:
            ["Output mode reported by the audio driver"]
        case .unknown:
            ["The audio driver reported a mode this app doesn't recognize."]
        }
    }

    /// The driver's mode string, separate from the user-facing output description.
    var driverModeLine: String? {
        switch self {
        case .lowImpedance: "Driver mode: Low Impedance"
        case .highImpedance: "Driver mode: High Impedance"
        case .oneVoltRMS(let raw), .highCapacitance(let raw), .unknown(let raw): "Driver mode: “\(raw)”"
        case .unsupported, .unreadable, .unplugged, .detecting: nil
        }
    }

    /// True when something is plugged in and the driver reported a mode.
    var isActiveMode: Bool {
        switch self {
        case .lowImpedance, .highImpedance, .oneVoltRMS, .highCapacitance, .unknown: true
        case .unsupported, .unreadable, .unplugged, .detecting: false
        }
    }

    /// One-line summary for diagnostics.
    var diagnosticName: String {
        switch self {
        case .unsupported: "unsupported"
        case .unreadable(let reason): "unreadable (\(reason))"
        case .unplugged: "unplugged"
        case .detecting: "detecting"
        case .lowImpedance: "lowImpedance"
        case .highImpedance: "highImpedance"
        case .oneVoltRMS: "oneVoltRMS"
        case .highCapacitance: "highCapacitance"
        case .unknown: "unknown"
        }
    }
}
