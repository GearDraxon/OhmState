import AppKit
import SwiftUI

/// Keeps the selected high-voltage mode recognizable at a glance.
struct HeadphoneStateIcon: View {
    let state: HeadphoneOutputState

    var body: some View {
        Image(systemName: state.menuBarSymbol)
            .font(.system(size: 40, weight: .regular))
            .overlay(alignment: .bottomTrailing) {
                if state == .highImpedance {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .offset(x: 8, y: 3)
                }
            }
            .frame(width: 52)
    }

    /// The menu-bar icon as a single template image.
    ///
    /// A MenuBarExtra label shows only one image: an HStack of the headphones and a bolt
    /// rendered as just the headphones. So the bolt is drawn into the same image instead.
    static func menuBarImage(for state: HeadphoneOutputState) -> NSImage {
        let symbol = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let headphones = NSImage(systemSymbolName: state.menuBarSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbol) else { return NSImage() }

        guard state == .highImpedance,
              let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold))
        else {
            headphones.isTemplate = true
            return headphones
        }

        // Bolt sits to the right, bottom-aligned with the earcups, like a badge.
        let gap: CGFloat = 1
        let size = NSSize(width: headphones.size.width + gap + bolt.size.width,
                          height: max(headphones.size.height, bolt.size.height))
        let image = NSImage(size: size, flipped: false) { _ in
            headphones.draw(in: NSRect(origin: NSPoint(x: 0, y: (size.height - headphones.size.height) / 2),
                                       size: headphones.size))
            bolt.draw(in: NSRect(origin: NSPoint(x: headphones.size.width + gap, y: 0), size: bolt.size))
            return true
        }
        image.isTemplate = true  // Lets the menu bar tint it for light/dark and highlight.
        return image
    }
}
