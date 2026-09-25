# OhmState

A small macOS app that shows which headphone output mode your Mac has selected on Macs
with the adaptive (high-impedance) headphone jack.

**Does my Mac have it?** Apple lists the compatible models in
[Use high-impedance headphones with your Mac](https://support.apple.com/en-us/108351).

macOS detects the load on the headphone jack and switches between a standard and a
high-voltage output, but never shows which one it chose. OhmState reads the choice from
Apple's audio driver (the `DCIDMode` property of the `AppleCS42L84Audio` IORegistry
service). It reports the mode macOS selected; it does **not** measure impedance.

| What macOS reports                  | OhmState shows                                         | Menu bar     |
|-------------------------------------|--------------------------------------------------------|--------------|
| Nothing in the jack                 | No headphones connected                                | icon         |
| Jack connected, mode not chosen yet | Detecting… (about 1.3 s after plugging in)             | icon …       |
| `Low Impedance`                     | Standard output · Up to 1.25 V RMS                      | icon         |
| `High Impedance`                    | High-voltage output · Up to 3 V RMS                     | icon + bolt  |
| Anything else                       | Unrecognized Mode, with the raw value shown            | icon ?       |
| Driver not present                  | Adaptive headphone output not detected on this Mac     | slashed icon |

[Apple documents](https://support.apple.com/en-us/108351) the two modes as up to 1.25 V RMS
for headphones below about 150 Ω, and up to 3 V RMS for 150–1000 Ω.

## Using it

- OhmState opens as a normal window showing the current mode. Plug in your headphones and
  check it.
- **Show in menu bar** keeps a live indicator in the menu bar after you close the window;
  the Dock icon then disappears. With it off, closing the window quits the app.
- **Open at login** (available when the menu-bar item is on) starts OhmState in the menu bar
  at login, without opening the window.
- **Diagnostics** in the window shows the raw driver values. **Copy Diagnostics** copies them,
  along with your Mac model and macOS version, for a bug report. Nothing else is collected,
  and the app makes no network connections.

Requires macOS 14 or later.

## Installing a downloaded build

OhmState isn't notarized, so macOS blocks it the first time:

1. Unzip it and move **OhmState.app** to **/Applications**. Open at login needs the app to
   stay in one place, so don't run it from Downloads.
2. Open it. When macOS says it can't verify the app, click **Done**.
3. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next
   to the OhmState message. Confirm when asked.

After that it opens normally. Or build it yourself from source; locally built apps aren't
blocked.

## Building

Open `OhmState.xcodeproj` in Xcode, choose the **OhmState** scheme, and press ⌘R.
Press ⌘U to run the tests.

From the command line:

    xcodebuild -project OhmState.xcodeproj -scheme OhmState -configuration Release -derivedDataPath build build
    open build/Build/Products/Release/OhmState.app

    xcodebuild test -project OhmState.xcodeproj -scheme OhmState -derivedDataPath build

No dependencies beyond Xcode. The app is signed ad hoc ("Sign to Run Locally").

## Checking it against macOS

    ioreg -r -c AppleCS42L84Audio -l -w0 | grep '"DCIDMode"'
    log stream --predicate 'subsystem == "io.github.geardraxon.OhmState"' --info

The app logs every state change with the raw `DCIDMode` value, so the two can be compared
while plugging and unplugging.

## How it works

See [NOTES.md](NOTES.md) for the details and the measurements behind them. In short:

- The mode is read directly with IOKit; the app never runs `ioreg`.
- The driver sends no notification when the mode changes. Instead, the app listens for
  macOS adding or removing the "External Headphones" audio device, then re-reads the mode
  for a few seconds until it settles. A 30-second check is kept as a safety net.
- It's sandboxed with no special entitlements, and needs no admin rights, Accessibility,
  Full Disk Access or other permissions.

## License

MIT. See [LICENSE](LICENSE).
