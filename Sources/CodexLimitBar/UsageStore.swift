import Foundation

enum UsageViewState: Sendable {
    case loading(previous: UsageSnapshot?)
    case loaded(UsageSnapshot)
    case failed(previous: UsageSnapshot?, failure: UsageFailure)

    var snapshot: UsageSnapshot? {
        switch self {
        case let .loading(previous), let .failed(previous, _):
            previous
        case let .loaded(snapshot):
            snapshot
        }
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var state: UsageViewState = .loading(previous: nil)
    @Published private(set) var isRefreshing = false

    private let provider: any CodexUsageProviding
    private let refreshInterval: Duration
    private var scheduleTask: Task<Void, Never>?

    init(
        provider: any CodexUsageProviding,
        refreshInterval: Duration = .seconds(15)
    ) {
        self.provider = provider
        self.refreshInterval = refreshInterval
    }

    func start() {
        guard scheduleTask == nil else { return }
        Task { await refreshNow() }
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await Task.sleep(for: self.refreshInterval)
                } catch {
                    return
                }
                await self.refreshNow()
            }
        }
    }

    func refresh() {
        Task { await refreshNow() }
    }

    func refreshNow() async {
        guard !isRefreshing else { return }
        let previous = state.snapshot
        isRefreshing = true
        state = .loading(previous: previous)

        do {
            state = .loaded(try await provider.fetchUsage())
        } catch let failure as UsageFailure {
            state = .failed(previous: previous, failure: failure)
        } catch {
            state = .failed(previous: previous, failure: .network)
        }

        isRefreshing = false
    }

    func stop() {
        scheduleTask?.cancel()
        scheduleTask = nil
    }
}
