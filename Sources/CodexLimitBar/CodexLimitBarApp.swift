import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchAtLogin = LaunchAtLogin()
    private let updater = AppUpdater()
    private var menuBar: MenuBarController?
    private var store: UsageStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let launchReason = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        let launchedAtLogin = launchReason == keyAELaunchedAsLogInItem
            || launchReason == keyAELaunchedAsServiceItem

        let authManager = ChatGPTAuthManager()
        let store = UsageStore(
            provider: LiveCodexUsageProvider(authSession: authManager),
            authenticator: authManager
        )
        self.store = store
        menuBar = MenuBarController(store: store, launchAtLogin: launchAtLogin, updater: updater)
        store.start()

        Task { @MainActor in
            launchAtLogin.offerSetupAtFirstLaunch()
            updater.start()
            if !launchedAtLogin { menuBar?.show() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBar?.show()
        return false
    }
}

@main
struct CodexLimitBarApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
