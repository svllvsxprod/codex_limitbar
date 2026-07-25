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
        let source = candidates.compactMap({ $0 }).lazy.compactMap(NSImage.init(contentsOf:)).first
            ?? NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: "Codex Limit Bar")!
        let iconSize = NSSize(width: 16, height: 16)
        let image = NSImage(size: iconSize, flipped: false) { rect in
            source.draw(
                in: rect,
                from: NSRect(origin: .zero, size: source.size),
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.size = iconSize
        image.isTemplate = true
        return image
    }()
}

struct LimitBarIconView: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: LimitBarIcon.image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Codex Limit Bar")
    }
}
