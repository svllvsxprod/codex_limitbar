import Foundation
import XCTest
@testable import CodexLimitBar

final class LocalChatGPTAuthLoaderTests: XCTestCase {
    func testMalformedCodexAuthFallsBackToOpenCode() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }

        try writePrivate(Data("not-json".utf8), to: home.appending(path: ".codex/auth.json"))
        try writePrivate(
            Data(#"{"openai":{"access":"token","accountId":"account"}}"#.utf8),
            to: home.appending(path: ".local/share/opencode/auth.json")
        )

        let auth = try LocalChatGPTAuthLoader(homeDirectory: home).load()

        XCTAssertEqual(auth.source, .openCode)
        XCTAssertEqual(auth.accountID, "account")
    }

    func testRejectsAuthReadableByOtherUsers() throws {
        let home = try makeTemporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let authURL = home.appending(path: ".local/share/opencode/auth.json")
        try writePrivate(
            Data(#"{"openai":{"access":"token","accountId":"account"}}"#.utf8),
            to: authURL
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: authURL.path
        )

        XCTAssertThrowsError(try LocalChatGPTAuthLoader(homeDirectory: home).load()) { error in
            XCTAssertEqual(error as? UsageFailure, .sourceUnavailable)
        }
    }

    private func makeTemporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePrivate(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
