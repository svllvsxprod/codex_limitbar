import Foundation
import XCTest
@testable import CodexLimitBar

final class KeychainOAuthCredentialStoreTests: XCTestCase {
    func testSavesLoadsAndDeletesCredentialWithoutEntitlements() throws {
        let store = KeychainOAuthCredentialStore(
            service: "local.svllvsx.codex-limitbar.tests.\(UUID().uuidString)",
            account: "openai"
        )
        defer { try? store.delete() }
        let credential = StoredOAuthCredential(
            accessToken: "access-test",
            refreshToken: "refresh-test",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
            accountID: "account-test"
        )

        try store.save(credential)

        XCTAssertEqual(try store.load(), credential)
        try store.delete()
        XCTAssertNil(try store.load())
    }
}
