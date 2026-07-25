import XCTest
@testable import CodexLimitBar

final class AuthenticationRetryTests: XCTestCase {
    func testRetriesAuthenticationFailureOnce() async throws {
        let operation = AuthenticationOperation(results: [
            .failure(.authentication),
            .success(42)
        ])

        let value = try await AuthenticationRetry.once(
            delay: .zero,
            operation: { try await operation.run() },
            retryOperation: { try await operation.run() }
        )

        XCTAssertEqual(value, 42)
        let attempts = await operation.attempts
        XCTAssertEqual(attempts, 2)
    }

    func testDoesNotRetryOtherFailures() async {
        let operation = AuthenticationOperation(results: [
            .failure(.network),
            .success(42)
        ])

        do {
            _ = try await AuthenticationRetry.once(
                delay: .zero,
                operation: { try await operation.run() },
                retryOperation: { try await operation.run() }
            )
            XCTFail("Expected network failure")
        } catch {
            XCTAssertEqual(error as? UsageFailure, .network)
        }

        let attempts = await operation.attempts
        XCTAssertEqual(attempts, 1)
    }
}

private actor AuthenticationOperation {
    private var results: [Result<Int, UsageFailure>]
    private(set) var attempts = 0

    init(results: [Result<Int, UsageFailure>]) {
        self.results = results
    }

    func run() throws -> Int {
        attempts += 1
        guard !results.isEmpty else { throw UsageFailure.authentication }
        return try results.removeFirst().get()
    }
}
