import ServiceManagement
import XCTest
@testable import CodexLimitBar

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    private let installedURL = URL(fileURLWithPath: "/Applications/CodexLimitBar.app")

    func testOpeningSettingsAndRefreshingNeverRegistersTheApp() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(service: service, appURL: installedURL)

        model.refresh()

        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testUserCanEnableAndDisableLaunchAtLogin() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(service: service, appURL: installedURL)

        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertEqual(service.registerCount, 1)

        model.setEnabled(false)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testExistingRegistrationIsPreservedAndSystemChangesAreRespected() {
        let service = FakeLoginItemService(status: .enabled)
        let model = LaunchAtLogin(service: service, appURL: installedURL)
        XCTAssertTrue(model.isEnabled)

        service.status = .requiresApproval
        model.refresh()

        XCTAssertFalse(model.isEnabled)
        XCTAssertTrue(model.requiresApproval)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testPendingApprovalOpensSettingsWithoutRegisteringAgain() {
        let service = FakeLoginItemService(status: .requiresApproval)
        var openedSettings = false
        let model = LaunchAtLogin(service: service, appURL: installedURL) {
            openedSettings = true
        }

        model.setEnabled(true)

        XCTAssertTrue(openedSettings)
        XCTAssertFalse(model.isEnabled)
        XCTAssertEqual(service.registerCount, 0)
    }

    func testRegistrationMayRequireApprovalInsteadOfBecomingEnabled() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.statusAfterRegistration = .requiresApproval
        let model = LaunchAtLogin(service: service, appURL: installedURL)

        model.setEnabled(true)

        XCTAssertTrue(model.requiresApproval)
        XCTAssertFalse(model.isEnabled)
        XCTAssertNil(model.errorMessage)
    }

    func testFailuresKeepActualSystemStateAndCanBeRetried() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.failure = NSError(domain: "LaunchAtLoginTests", code: 1)
        let model = LaunchAtLogin(service: service, appURL: installedURL)

        model.setEnabled(true)
        XCTAssertFalse(model.isEnabled)
        XCTAssertNotNil(model.errorMessage)

        service.failure = nil
        model.setEnabled(true)
        XCTAssertTrue(model.isEnabled)
        XCTAssertNil(model.errorMessage)

        service.failure = NSError(domain: "LaunchAtLoginTests", code: 2)
        model.setEnabled(false)
        XCTAssertTrue(model.isEnabled)
        XCTAssertNotNil(model.errorMessage)
    }

    func testAppOutsideApplicationsCannotRegisterButCanRemoveExistingRegistration() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(
            service: service,
            appURL: URL(fileURLWithPath: "/Volumes/Installer/CodexLimitBar.app")
        )

        XCTAssertFalse(model.canChange)
        model.setEnabled(true)
        XCTAssertEqual(service.registerCount, 0)

        service.status = .enabled
        model.refresh()
        XCTAssertTrue(model.canChange)
        model.setEnabled(false)
        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testUserApplicationsFolderIsSupported() {
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(
            service: service,
            appURL: FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Applications/CodexLimitBar.app")
        )
        XCTAssertTrue(model.isInstalled)
    }

    func testInitialSetupIsOfferedOnceAndDoesNotEnableAnythingWithoutConsent() {
        let suite = "LaunchAtLoginTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = FakeLoginItemService(status: .notRegistered)
        let model = LaunchAtLogin(service: service, appURL: installedURL, defaults: defaults)

        XCTAssertTrue(model.takeInitialSetupOffer())
        XCTAssertFalse(model.takeInitialSetupOffer())
        let relaunched = LaunchAtLogin(service: service, appURL: installedURL, defaults: defaults)
        XCTAssertFalse(relaunched.takeInitialSetupOffer())
        XCTAssertEqual(service.registerCount, 0)
    }

    func testAlreadyEnabledAutostartDoesNotPromptEvenAfterLaterSystemDisable() {
        let suite = "LaunchAtLoginTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = FakeLoginItemService(status: .enabled)
        let model = LaunchAtLogin(service: service, appURL: installedURL, defaults: defaults)

        XCTAssertFalse(model.takeInitialSetupOffer())
        service.status = .requiresApproval
        XCTAssertFalse(model.takeInitialSetupOffer())
        XCTAssertEqual(service.registerCount, 0)
    }

    func testRunningFromDiskImageDoesNotConsumeFirstInstalledLaunchOffer() {
        let suite = "LaunchAtLoginTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = FakeLoginItemService(status: .notRegistered)
        let diskImage = LaunchAtLogin(
            service: service,
            appURL: URL(fileURLWithPath: "/Volumes/Installer/CodexLimitBar.app"),
            defaults: defaults
        )
        XCTAssertFalse(diskImage.takeInitialSetupOffer())

        let installed = LaunchAtLogin(service: service, appURL: installedURL, defaults: defaults)
        XCTAssertTrue(installed.takeInitialSetupOffer())
    }
}

@MainActor
private final class FakeLoginItemService: LoginItemServicing {
    var status: SMAppService.Status
    var statusAfterRegistration: SMAppService.Status = .enabled
    var failure: Error?
    var registerCount = 0
    var unregisterCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let failure { throw failure }
        status = statusAfterRegistration
    }

    func unregister() throws {
        unregisterCount += 1
        if let failure { throw failure }
        status = .notRegistered
    }
}
