import Foundation
import XCTest
@testable import CodexLimitBar

final class DailyUsageTrackerTests: XCTestCase {
    func testAccumulatesOnlyUsageIncreasesDuringTheSameDay() {
        let defaults = makeDefaults()
        let tracker = DailyUsageTracker(defaults: defaults, calendar: utcCalendar())

        XCTAssertEqual(tracker.record(snapshot(usedPercent: 25), at: date(day: 1, hour: 8)), 0)
        XCTAssertEqual(tracker.record(snapshot(usedPercent: 30), at: date(day: 1, hour: 9)), 5)
        XCTAssertEqual(tracker.record(snapshot(usedPercent: 34), at: date(day: 1, hour: 10)), 9)
    }

    func testKeepsAccumulatedUsageAcrossResetAndContinuesFromZero() {
        let defaults = makeDefaults()
        let tracker = DailyUsageTracker(defaults: defaults, calendar: utcCalendar())

        _ = tracker.record(snapshot(usedPercent: 20), at: date(day: 1, hour: 8))
        _ = tracker.record(snapshot(usedPercent: 30), at: date(day: 1, hour: 9))
        XCTAssertEqual(tracker.record(snapshot(usedPercent: 0), at: date(day: 1, hour: 10)), 10)
        XCTAssertEqual(tracker.record(snapshot(usedPercent: 4), at: date(day: 1, hour: 11)), 14)
    }

    func testStartsANewCounterOnTheNextCalendarDay() {
        let defaults = makeDefaults()
        let tracker = DailyUsageTracker(defaults: defaults, calendar: utcCalendar())

        _ = tracker.record(snapshot(usedPercent: 20), at: date(day: 1, hour: 8))
        _ = tracker.record(snapshot(usedPercent: 30), at: date(day: 1, hour: 9))

        XCTAssertEqual(tracker.record(snapshot(usedPercent: 31), at: date(day: 2, hour: 8)), 0)
        XCTAssertEqual(tracker.record(snapshot(usedPercent: 35), at: date(day: 2, hour: 9)), 4)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "DailyUsageTrackerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int, hour: Int) -> Date {
        DateComponents(
            calendar: utcCalendar(),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 8,
            day: day,
            hour: hour
        ).date!
    }

    private func snapshot(usedPercent: Int) -> UsageSnapshot {
        UsageSnapshot(
            limits: [
                UsageLimit(
                    id: "codex",
                    name: "Codex",
                    windows: [
                        UsageWindow(
                            usedPercent: usedPercent,
                            windowDurationMinutes: 300,
                            resetsAt: nil
                        )
                    ]
                )
            ],
            planType: "plus",
            fetchedAt: Date(),
            source: .codexLimitBar
        )
    }
}
