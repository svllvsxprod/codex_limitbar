import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        LaunchAtLogin.registerIfInstalled()
    }
}

@main
struct CodexLimitBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore(provider: LiveCodexUsageProvider())

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(store: store)
        } label: {
            LimitBarIconView(size: 17)
        }
        .menuBarExtraStyle(.window)
    }
}
