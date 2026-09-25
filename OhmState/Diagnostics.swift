import AppKit

/// Plain-text diagnostics suitable for pasting into a bug report.
enum Diagnostics {
    /// Pass `date` to stamp the report (used when copying; omitted on screen so the
    /// view doesn't need to redraw every second).
    static func report(reading: CS42L84Reading, state: HeadphoneOutputState, date: Date? = nil) -> String {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        var lines = [
            "OhmState \(appVersion) (\(build))",
            "Mac model: \(macModel ?? "unknown")",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "\(CS42L84Reader.serviceClass) found: \(reading.serviceFound ? "yes" : "no")",
        ]
        if reading.serviceFound {
            lines.append("DCIDMode (raw): \(reading.dcidMode.map { "\"\($0)\"" } ?? "unavailable")")
            if let problem = reading.dcidModeProblem { lines.append("DCIDMode problem: \(problem)") }
            lines.append("Supports DCID: \(describe(reading.supportsDCID))")
            lines.append("HPDetect: \(describe(reading.headphoneDetect))")
            lines.append("DetectConfidence: \(reading.detectConfidence ?? "unavailable")")
        }
        lines.append("Interpreted state: \(state.diagnosticName)")
        if let date { lines.append("Read at: \(date.ISO8601Format())") }
        return lines.joined(separator: "\n")
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Hardware model identifier such as "MacBookPro18,3".
    static let macModel: String? = {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }()

    private static func describe(_ value: Bool?) -> String {
        value.map { $0 ? "yes" : "no" } ?? "unavailable"
    }
}
