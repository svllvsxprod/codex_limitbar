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
    @StateObject private var store: UsageStore

    init() {
        let authManager = ChatGPTAuthManager()
        _store = StateObject(
            wrappedValue: UsageStore(
                provider: LiveCodexUsageProvider(authSession: authManager),
                authenticator: authManager
            )
        )
    }

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(store: store)
        } label: {
            LimitBarIconView(size: 17)
        }
        .menuBarExtraStyle(.window)
    }
}
