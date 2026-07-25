import Foundation
import XCTest
@testable import CodexLimitBar

final class BackendUsageParserTests: XCTestCase {
    func testParsesMainAndAdditionalLimits() throws {
        let data = Data(
            """
            {
              "plan_type": "plus",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 36,
                  "limit_window_seconds": 18000,
                  "reset_at": 1800000000
                },
                "secondary_window": {
                  "used_percent": 80,
                  "limit_window_seconds": 604800,
                  "reset_at": 1800100000
                }
              },
              "additional_rate_limits": [
                {
                  "limit_name": "Codex Spark",
                  "metered_feature": "codex_spark",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 5,
                      "limit_window_seconds": 604800,
                      "reset_at": 1800200000
                    }
                  }
                }
              ],
              "unknown_future_field": true
            }
            """.utf8
        )

        let snapshot = try BackendUsageParser.parse(
            data: data,
            source: .codexCLI,
            fetchedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.planType, "plus")
        XCTAssertEqual(snapshot.source, .codexCLI)
        XCTAssertEqual(snapshot.limits.map(\.id), ["codex", "codex_spark"])
        XCTAssertEqual(snapshot.limits[0].windows.map(\.remainingPercent), [64, 20])
        XCTAssertEqual(snapshot.limits[0].windows.map(\.windowDurationMinutes), [300, 10_080])
        XCTAssertEqual(snapshot.limits[1].windows.first?.remainingPercent, 95)
    }

    func testRejectsResponseWithoutUsageWindows() {
        let data = Data(#"{"plan_type":"plus","rate_limit":null}"#.utf8)

        XCTAssertThrowsError(
            try BackendUsageParser.parse(
                data: data,
                source: .openCode,
                fetchedAt: Date()
            )
        ) { error in
            XCTAssertEqual(error as? UsageFailure, .malformedResponse)
        }
    }

    func testClampsPercentages() throws {
        let data = Data(
            #"{"rate_limit":{"primary_window":{"used_percent":140}}}"#.utf8
        )

        let snapshot = try BackendUsageParser.parse(
            data: data,
            source: .openCode,
            fetchedAt: Date()
        )

        XCTAssertEqual(snapshot.limits[0].windows[0].usedPercent, 100)
        XCTAssertEqual(snapshot.limits[0].windows[0].remainingPercent, 0)
    }
}
