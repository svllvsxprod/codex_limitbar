import AppKit
import SwiftUI

@MainActor
enum LimitBarIcon {
    static let image: NSImage = {
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let candidates = [
            Bundle.main.url(forResource: "limitbar-mark", withExtension: "svg"),
            executableDirectory
                .appending(path: "CodexLimitBar_CodexLimitBar.bundle")
                .appending(path: "limitbar-mark.svg")
        ]
        let mark = candidates.compactMap({ $0 }).lazy.compactMap(NSImage.init(contentsOf:)).first
            ?? NSImage(
                systemSymbolName: "gauge.with.dots.needle.67percent",
                accessibilityDescription: L10n.text("app_name")
            )!
        let iconSize = NSSize(width: 16, height: 16)
        let image = NSImage(size: iconSize, flipped: false) { rect in
            mark.draw(
                in: rect,
                from: NSRect(origin: .zero, size: mark.size),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.size = iconSize
        image.isTemplate = true
        return image
    }()

    static func percentageLabel(remainingPercent: Int?) -> String {
        guard let remainingPercent else { return "--%" }
        return "\(max(0, min(100, remainingPercent)))%"
    }

    static func accessibilityLabel(remainingPercent: Int?) -> String {
        guard let remainingPercent else { return L10n.text("app_name") }
        return L10n.format(
            "menu_bar_accessibility_format",
            max(0, min(100, remainingPercent))
        )
    }
}

struct LimitBarIconView: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: LimitBarIcon.image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(L10n.text("app_name")))
    }
}
