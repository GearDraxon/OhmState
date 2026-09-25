import Testing
@testable import OhmState

private func reading(_ mode: String?, hpDetect: Bool? = nil) -> CS42L84Reading {
    CS42L84Reading(
        serviceFound: true,
        dcidMode: mode,
        dcidModeProblem: mode == nil ? "DCIDMode property is missing" : nil,
        headphoneDetect: hpDetect
    )
}

@Suite("Interpreting DCIDMode")
struct InterpretationTests {
    @Test func noServiceIsUnsupported() {
        #expect(HeadphoneOutputState(.notFound) == .unsupported)
    }

    @Test func missingPropertyIsUnreadable() {
        #expect(HeadphoneOutputState(reading(nil)) == .unreadable(reason: "DCIDMode property is missing"))
    }

    /// The three strings verified on hardware (HD 598 SE → Low, HD 6XX → High).
    @Test(arguments: [
        ("Unplugged", HeadphoneOutputState.unplugged),
        ("Low Impedance", .lowImpedance),
        ("High Impedance", .highImpedance),
    ])
    func verifiedModes(raw: String, expected: HeadphoneOutputState) {
        #expect(HeadphoneOutputState(reading(raw)) == expected)
        #expect(HeadphoneOutputState(reading(raw, hpDetect: false)) == expected)
    }

    /// For ~1.3 s after plug-in the driver reports HPDetect = Yes while DCIDMode is still "Unplugged".
    @Test func jackConnectedBeforeModeChosenIsDetecting() {
        #expect(HeadphoneOutputState(reading("Unplugged", hpDetect: true)) == .detecting)
        #expect(HeadphoneOutputState(reading("High Impedance", hpDetect: true)) == .highImpedance)
    }

    /// Advertised in the driver's IOReport legend but never observed; the spellings are guesses.
    @Test(arguments: ["1VRMS", "1 V RMS", "One Volt RMS"])
    func oneVoltSpellings(raw: String) {
        #expect(HeadphoneOutputState(reading(raw)) == .oneVoltRMS(raw: raw))
    }

    @Test(arguments: ["HiCapacitance", "High Capacitance", "high-capacitance"])
    func highCapacitanceSpellings(raw: String) {
        #expect(HeadphoneOutputState(reading(raw)) == .highCapacitance(raw: raw))
    }

    @Test(arguments: ["Weird", "", "Medium Impedance"])
    func unrecognizedStringsAreUnknown(raw: String) {
        #expect(HeadphoneOutputState(reading(raw)) == .unknown(raw: raw))
    }
}

@Suite("Presentation")
struct PresentationTests {
    @Test func unknownModeShowsRawString() {
        let state = HeadphoneOutputState(reading("Something New"))
        #expect(state.driverModeLine?.contains("Something New") == true)
        #expect(state.menuBarText == "?")
    }

    @Test func knownModesExplainTheSelectedOutput() {
        #expect(HeadphoneOutputState.highImpedance.title == "High-voltage output")
        #expect(HeadphoneOutputState.lowImpedance.title == "Standard output")
        #expect(HeadphoneOutputState.highImpedance.details == ["Up to 3 V RMS"])
        #expect(HeadphoneOutputState.lowImpedance.details == ["Up to 1.25 V RMS"])
        #expect(HeadphoneOutputState.highImpedance.driverModeLine == "Driver mode: High Impedance")
    }

    @Test func menuBarText() {
        #expect(HeadphoneOutputState.highImpedance.menuBarText == nil)
        #expect(HeadphoneOutputState.lowImpedance.menuBarText == nil)
        #expect(HeadphoneOutputState.unplugged.menuBarText == nil)
        #expect(HeadphoneOutputState.unsupported.menuBarSymbol == "headphones.slash")
    }
}

@Suite("Diagnostics")
struct DiagnosticsTests {
    @Test func includesRawModeAndInterpretation() {
        let r = reading("High Impedance", hpDetect: true)
        let report = Diagnostics.report(reading: r, state: HeadphoneOutputState(r))
        #expect(report.contains("AppleCS42L84Audio found: yes"))
        #expect(report.contains(#"DCIDMode (raw): "High Impedance""#))
        #expect(report.contains("HPDetect: yes"))
        #expect(report.contains("Interpreted state: highImpedance"))
        #expect(!report.contains("Read at:"))
    }

    @Test func unsupportedOmitsDriverFields() {
        let report = Diagnostics.report(reading: .notFound, state: .unsupported, date: .now)
        #expect(report.contains("AppleCS42L84Audio found: no"))
        #expect(!report.contains("DCIDMode"))
        #expect(report.contains("Read at:"))
    }
}

/// Reads the real IORegistry. Skipped on Macs without the adaptive headphone jack.
@Suite("Live IORegistry", .enabled(if: CS42L84Reader().read().serviceFound))
struct LiveReaderTests {
    @Test func readsDCIDModeAsString() {
        let r = CS42L84Reader().read()
        #expect(r.dcidMode != nil)
        #expect(r.dcidModeProblem == nil)
    }

    @Test func repeatedReadsAreStable() {
        let reader = CS42L84Reader()
        let first = reader.read()
        for _ in 0..<1_000 {
            #expect(reader.read().serviceFound == first.serviceFound)
        }
    }
}

@Suite("Review fixes")
struct ReviewFixTests {
    /// Low/High carry voltage claims, so only the exact verified strings may map to them.
    @Test(arguments: ["LowImpedance", "low_impedance", "HIGH IMPEDANCE", "HighImpedance"])
    func lowHighVariantsAreNotTrusted(raw: String) {
        let state = HeadphoneOutputState(reading(raw))
        #expect(state == .unknown(raw: raw))
        #expect(state.driverModeLine?.contains(raw) == true)
    }
}

/// Stand-in for the IOKit reader; tests set `next` to simulate the driver.
private final class FakeReader: CS42L84ReadingSource {
    var next: CS42L84Reading
    init(_ reading: CS42L84Reading) { next = reading }
    func read() -> CS42L84Reading { next }
}

@MainActor
@Suite("Monitor")
struct MonitorTests {
    /// If the driver is missing at launch (e.g. restarting), the monitor must keep checking.
    @Test func picksUpServiceThatAppearsAfterLaunch() async throws {
        let fake = FakeReader(.notFound)
        let monitor = HeadphoneImpedanceMonitor(reader: fake, safetyPollInterval: .milliseconds(50))
        #expect(monitor.state == .unsupported)

        fake.next = CS42L84Reading(serviceFound: true, dcidMode: "High Impedance")
        let deadline = ContinuousClock.now + .seconds(2)
        while monitor.state != .highImpedance, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(monitor.state == .highImpedance)
    }

    @Test func refreshPublishesChanges() {
        let fake = FakeReader(CS42L84Reading(serviceFound: true, dcidMode: "Unplugged"))
        let monitor = HeadphoneImpedanceMonitor(reader: fake)
        #expect(monitor.state == .unplugged)
        fake.next = CS42L84Reading(serviceFound: true, dcidMode: "Low Impedance")
        monitor.refresh()
        #expect(monitor.state == .lowImpedance)
    }
}
