import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static func registerIfInstalled() {
        guard isInstalledApplication(Bundle.main.bundleURL) else { return }

        let service = SMAppService.mainApp
        guard service.status == .notRegistered else { return }
        try? service.register()
    }

    private static func isInstalledApplication(_ appURL: URL) -> Bool {
        let path = appURL.resolvingSymlinksInPath().standardizedFileURL.path
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true).path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Applications", directoryHint: .isDirectory)
            .path
        return path.hasPrefix(systemApplications + "/")
            || path.hasPrefix(userApplications + "/")
    }
}
