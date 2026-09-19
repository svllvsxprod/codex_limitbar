import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var observations = Set<AnyCancellable>()

    init(store: UsageStore, launchAtLogin: LaunchAtLogin, updater: AppUpdater) {
        super.init()
        let hosting = NSHostingController(rootView: UsageMenuView(
            store: store,
            launchAtLogin: launchAtLogin,
            updater: updater
        ))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false

        hosting.publisher(for: \.preferredContentSize)
            .sink { [weak self] size in
                guard size.width > 0, size.height > 0 else { return }
                self?.popover.contentSize = size
            }
            .store(in: &observations)

        item.button?.target = self
        item.button?.action = #selector(toggle)
        if let button = item.button {
            button.image = LimitBarIcon.image
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        }
        store.$state
            .sink { [weak self] state in
                let remaining = state.snapshot?.lowestRemainingPercent
                self?.item.button?.title = " " + LimitBarIcon.percentageLabel(remainingPercent: remaining)
                self?.item.button?.setAccessibilityLabel(LimitBarIcon.accessibilityLabel(remainingPercent: remaining))
            }
            .store(in: &observations)

        updater.beforePresentation = { [weak self] in
            self?.popover.performClose(nil)
        }
    }

    func show() {
        guard let button = item.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func toggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show()
        }
    }

}
