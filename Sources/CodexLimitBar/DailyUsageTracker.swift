import Foundation

final class DailyUsageTracker {
    private struct State: Codable {
        let day: String
        let lastUsedPercent: Int
        let spentPercent: Int
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        storageKey: String = "local.svllvsx.codex-limitbar.daily-usage"
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.storageKey = storageKey
    }

    func record(_ snapshot: UsageSnapshot, at date: Date = Date()) -> Int {
        guard
            let window = snapshot.limits.first(where: { $0.id == "codex" })?.windows.first
        else {
            return current(at: date)
        }

        let day = dayIdentifier(for: date)
        let previous = load()
        let spentPercent: Int
        if let previous, previous.day == day {
            spentPercent = previous.spentPercent
                + max(0, window.usedPercent - previous.lastUsedPercent)
        } else {
            spentPercent = 0
        }
        save(
            State(
                day: day,
                lastUsedPercent: window.usedPercent,
                spentPercent: spentPercent
            )
        )
        return spentPercent
    }

    func current(at date: Date = Date()) -> Int {
        guard let state = load(), state.day == dayIdentifier(for: date) else { return 0 }
        return state.spentPercent
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func load() -> State? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    private func save(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
