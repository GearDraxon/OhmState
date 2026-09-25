# OhmState — design notes

Facts the code can't tell you: what the driver actually does, measured on an Apple Silicon
MacBook Pro running macOS 27 with a Sennheiser HD 598 SE (nominal 50 Ω) and HD 6XX
(nominal 300 Ω). Read this before changing behavior.

## The data source

`AppleCS42L84Audio` (IOService plane) publishes these properties:

| Property           | Observed values                                                  | Used for |
|--------------------|------------------------------------------------------------------|----------|
| `DCIDMode`         | `"Unplugged"`, `"Low Impedance"`, `"High Impedance"`             | The mode |
| `HPDetect`         | `No` / `Yes`                                                     | "Detecting…" state, diagnostics |
| `DetectConfidence` | `"CompleteFinal"` when unplugged, `"NoneNoNotify"` while plugged | Diagnostics only |
| `Supports DCID`    | `Yes`                                                            | Diagnostics only |

- **Verified:** nothing plugged in → `Unplugged`; HD 598 SE → `Low Impedance`;
  HD 6XX → `High Impedance`. Each matched `ioreg -r -c AppleCS42L84Audio -l -w0`.
- **Not verified:** the driver's `IOReportLegend` also lists `Codec Output.1VRMS` and
  `Codec Output.HiCapacitance`. These are counter channels, not a list of `DCIDMode` values
  (`Unplugged` isn't in the legend), and neither has been seen as a `DCIDMode` string. The app
  matches a few guessed spellings loosely and always shows the raw string.
- **Low/High are matched only by their exact verified strings**, because they carry voltage
  claims. Any variant (`LowImpedance`, `low_impedance`, …) is shown as unrecognized with its
  raw value.
- **`DetectConfidence` is not a "detection finished" flag**: it reads `NoneNoNotify` the
  whole time headphones are plugged in.

## Plug-in timing, and why updates work the way they do

Two plug/unplug cycles, recorded with IOKit interest notifications, a CoreAudio device-list
listener, and `DCIDMode` read at 20 Hz:

| Event    | `HPDetect` | CoreAudio device list              | `DCIDMode` |
|----------|------------|------------------------------------|------------|
| 6XX in   | Yes at t   | "External Headphones" added +62 ms | `High Impedance` +1.30 s |
| 6XX out  | No at t    | removed +56 ms                     | `Unplugged` at t |
| 598 in   | Yes at t   | added +9 ms                        | `Low Impedance` +1.40 s |
| 598 out  | No at t    | removed +45 ms                     | `Unplugged` at t |

- **The driver sends no IOKit notification** (`kIOGeneralInterest` and `kIOBusyInterest`
  stayed silent), and IOKit has no generic property-changed notification. The app listens
  for CoreAudio `kAudioHardwarePropertyDevices` changes instead.
- **After each device change it re-reads `DCIDMode` every 250 ms for 5 s**, because the mode
  appears ~1.3–1.4 s after the device. A 30 s safety poll covers anything missed, and 1 s
  polling is the fallback if the CoreAudio listener can't be registered.
- **"Detecting…"** is `HPDetect == Yes` while `DCIDMode == "Unplugged"`: the gap after a
  plug-in, which would otherwise read as "No headphones connected".
- **Idle cost:** ~4 wakeups/min, ~0.01 s CPU/min, ~30 MB memory (about 6 MB of it the
  CoreAudio client).

## Things that look wrong but aren't

Each has a comment at the code. Check it before "fixing" one.

- `HeadphoneImpedanceMonitor.refresh()` only assigns when the reading changed. Publishing on
  every read re-renders the whole scene, including the menu-bar item, and costs real CPU.
- The monitor keeps polling even when the driver is missing at launch, in case it's
  restarting.
- `CS42L84Reader` drops its cached handle when the entry leaves the service plane: a
  terminated entry's handle stays valid but returns stale properties.
- `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false`: SwiftUI's
  default quits a single-window app when the window closes, even with a menu-bar item.
  `windowWillClose` decides instead, and `isQuitting` ignores the second close that
  `terminate` triggers.
- On a login launch the window is closed synchronously in `applicationDidFinishLaunching`, so
  it's never drawn.
- Turning off the menu-bar item is handled at the app level (`OhmStateApp.menuBarItemRemoved`),
  not in the window, because it can happen with the window closed (⌘-drag). It removes the
  login item, restores the menu-bar item if that fails, and quits if nothing is left on screen.
- The menu-bar icon is one composed image (`HeadphoneStateIcon.menuBarImage`): a
  `MenuBarExtra` label shows only one image, so a headphones + bolt `HStack` shows no bolt.

## Rules

- **Don't change the bundle identifier** (`io.github.geardraxon.OhmState`). Preferences, the
  sandbox container and the login item are keyed to it; changing it resets every user's
  settings.
- **Wording:** the app reports the mode macOS selected and never claims to measure
  impedance. "Up to 1.25 V RMS" below ~150 Ω and "up to 3 V RMS" for 150–1000 Ω are
  [Apple's figures](https://support.apple.com/en-us/108351). Unverified modes make no voltage
  claim.
- App Sandbox and Hardened Runtime stay on; nothing needs extra entitlements.
