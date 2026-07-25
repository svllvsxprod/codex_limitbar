import Foundation
import XCTest
@testable import CodexLimitBar

final class PublicServiceConnectivityGateTests: XCTestCase {
    func testAllowsOpenAIWhenAnyPublicServiceIsReachable() async {
        let reachableHost = "www.speedtest.net"
        let gate = PublicServiceConnectivityGate { url in
            url.host == reachableHost
        }

        let isAllowed = await gate.allowsOpenAIRequest()
        XCTAssertTrue(isAllowed)
    }

    func testBlocksOpenAIWhenEveryPublicServiceIsUnavailable() async {
        let gate = PublicServiceConnectivityGate { _ in false }

        let isAllowed = await gate.allowsOpenAIRequest()
        XCTAssertFalse(isAllowed)
    }

    func testProviderStopsBeforeAuthWhenGateBlocks() async {
        let provider = LiveCodexUsageProvider(requestGate: DenyOpenAIRequestGate())

        do {
            _ = try await provider.fetchUsage()
            XCTFail("Expected VPN gate failure")
        } catch {
            XCTAssertEqual(error as? UsageFailure, .vpnUnavailable)
        }
    }
}

private struct DenyOpenAIRequestGate: OpenAIRequestGating {
    func allowsOpenAIRequest() async -> Bool { false }
}
