import AppKit
import Foundation
import XCTest
@testable import CodexLimitBar

final class UsageStoreTests: XCTestCase {
    @MainActor
    func testDefaultRefreshIntervalIsThreeMinutes() {
        XCTAssertEqual(UsageStore.defaultRefreshInterval, .seconds(180))
    }

    @MainActor
    func testKeepsLastSnapshotWhenRefreshFails() async {
        let snapshot = UsageSnapshot(
            limits: [
                UsageLimit(
                    id: "codex",
                    name: "Codex",
                    windows: [
                        UsageWindow(
                            usedPercent: 25,
                            windowDurationMinutes: 300,
                            resetsAt: nil
                        )
                    ]
                )
            ],
            planType: "plus",
            fetchedAt: Date(timeIntervalSince1970: 100),
            source: .codexCLI
        )
        let provider = SequenceProvider(outcomes: [
            .success(snapshot),
            .failure(.network)
        ])
        let store = UsageStore(provider: provider)

        await store.refreshNow()
        await store.refreshNow()

        guard case let .failed(previous, failure) = store.state else {
            return XCTFail("Expected stale failure state")
        }
        XCTAssertEqual(previous, snapshot)
        XCTAssertEqual(failure, .network)
    }

    @MainActor
    func testCoalescesConcurrentRefreshes() async {
        let provider = CountingProvider()
        let store = UsageStore(provider: provider)

        async let first: Void = store.refreshNow()
        async let second: Void = store.refreshNow()
        _ = await (first, second)

        let fetchCount = await provider.fetchCount
        XCTAssertEqual(fetchCount, 1)
    }

    @MainActor
    func testRefreshesPeriodicallyOnlyUntilStopped() async throws {
        let provider = CountingProvider()
        let store = UsageStore(provider: provider, refreshInterval: .milliseconds(25))

        store.start()
        try await Task.sleep(for: .milliseconds(90))
        store.stop()

        let countAtStop = await provider.fetchCount
        XCTAssertGreaterThanOrEqual(countAtStop, 2)

        try await Task.sleep(for: .milliseconds(60))
        let countAfterStop = await provider.fetchCount
        XCTAssertEqual(countAfterStop, countAtStop)
    }

    @MainActor
    func testRefreshesAfterWorkspaceWake() async throws {
        let provider = CountingProvider()
        let store = UsageStore(
            provider: provider,
            wakeRefreshDelays: [.milliseconds(10), .milliseconds(10)]
        )

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: NSWorkspace.shared
        )
        try await Task.sleep(for: .milliseconds(180))

        let fetchCount = await provider.fetchCount
        XCTAssertEqual(fetchCount, 2)
        withExtendedLifetime(store) {}
    }
}

private actor SequenceProvider: CodexUsageProviding {
    enum Outcome: Sendable {
        case success(UsageSnapshot)
        case failure(UsageFailure)
    }

    private var outcomes: [Outcome]

    init(outcomes: [Outcome]) {
        self.outcomes = outcomes
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !outcomes.isEmpty else { throw UsageFailure.sourceUnavailable }
        switch outcomes.removeFirst() {
        case let .success(snapshot):
            return snapshot
        case let .failure(failure):
            throw failure
        }
    }
}

private actor CountingProvider: CodexUsageProviding {
    private(set) var fetchCount = 0

    func fetchUsage() async throws -> UsageSnapshot {
        fetchCount += 1
        try await Task.sleep(for: .milliseconds(50))
        return UsageSnapshot(
            limits: [
                UsageLimit(
                    id: "codex",
                    name: "Codex",
                    windows: [UsageWindow(usedPercent: 1, windowDurationMinutes: 300, resetsAt: nil)]
                )
            ],
            planType: "plus",
            fetchedAt: Date(),
            source: .openCode
        )
    }
}
