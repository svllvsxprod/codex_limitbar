import AppKit
import Combine
import ServiceManagement

@MainActor
protocol LoginItemServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemServicing {}

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    let isInstalled: Bool
    private let service: any LoginItemServicing
    private let openSettings: () -> Void
    private let defaults: UserDefaults
    private static let setupOfferedKey = "launch-at-login.setup-offered"

    init(
        service: any LoginItemServicing = SMAppService.mainApp,
        appURL: URL = Bundle.main.bundleURL,
        defaults: UserDefaults = .standard,
        openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    ) {
        self.service = service
        self.openSettings = openSettings
        self.defaults = defaults
        isInstalled = Self.isInstalledApplication(appURL)
        status = service.status
    }

    var isEnabled: Bool { status == .enabled }
    var requiresApproval: Bool { status == .requiresApproval }
    var canChange: Bool { isInstalled || isEnabled || requiresApproval }

    var statusMessage: String {
        if requiresApproval { return L10n.text("launch_at_login_approval") }
        if isEnabled { return L10n.text("launch_at_login_enabled") }
        if !isInstalled { return L10n.text("launch_at_login_install") }
        if status == .notFound { return L10n.text("launch_at_login_unavailable") }
        return L10n.text("launch_at_login_description")
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        refresh()
        errorMessage = nil
        guard enabled != isEnabled else { return }

        if enabled && requiresApproval {
            openSystemSettings()
            return
        }
        guard !enabled || isInstalled else { return }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = L10n.format(
                "launch_at_login_error_format",
                error.localizedDescription
            )
        }
        refresh()
    }

    func openSystemSettings() {
        openSettings()
    }

    func takeInitialSetupOffer() -> Bool {
        refresh()
        guard isInstalled, !defaults.bool(forKey: Self.setupOfferedKey) else { return false }
        defaults.set(true, forKey: Self.setupOfferedKey)
        return !isEnabled
    }

    func offerSetupAtFirstLaunch() {
        guard takeInitialSetupOffer() else { return }

        let alert = NSAlert()
        alert.messageText = L10n.text("launch_at_login_prompt_title")
        alert.informativeText = L10n.text("launch_at_login_prompt_description")
        alert.addButton(withTitle: L10n.text("launch_at_login_enable"))
        alert.addButton(withTitle: L10n.text("launch_at_login_later"))
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let alreadyRequiresApproval = requiresApproval
        setEnabled(true)
        if requiresApproval {
            if !alreadyRequiresApproval { openSystemSettings() }
        } else if let errorMessage {
            let failureAlert = NSAlert()
            failureAlert.alertStyle = .warning
            failureAlert.messageText = L10n.text("launch_at_login_prompt_title")
            failureAlert.informativeText = errorMessage
            failureAlert.addButton(withTitle: L10n.text("ok"))
            failureAlert.runModal()
        }
    }

    private static func isInstalledApplication(_ appURL: URL) -> Bool {
        guard appURL.pathExtension == "app" else { return false }
        let path = appURL.resolvingSymlinksInPath().standardizedFileURL.path
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true).path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Applications", directoryHint: .isDirectory)
            .path
        return path.hasPrefix(systemApplications + "/")
            || path.hasPrefix(userApplications + "/")
    }
}
