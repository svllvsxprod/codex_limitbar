import AppKit
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

enum ChatGPTSignInState: Equatable, Sendable {
    case idle
    case starting
    case waitingForUser(code: String)
    case failed(UsageFailure)
}

@MainActor
final class UsageStore: NSObject, ObservableObject {
    static let defaultRefreshInterval: Duration = .seconds(60)

    @Published private(set) var state: UsageViewState = .loading(previous: nil)
    @Published private(set) var isRefreshing = false
    @Published private(set) var signInState: ChatGPTSignInState = .idle

    private let provider: any CodexUsageProviding
    private let authenticator: (any ChatGPTAuthenticating)?
    private let refreshInterval: Duration
    private let wakeRefreshDelays: [Duration]
    private var scheduleTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var signInTask: Task<Void, Never>?

    init(
        provider: any CodexUsageProviding,
        authenticator: (any ChatGPTAuthenticating)? = nil,
        refreshInterval: Duration = UsageStore.defaultRefreshInterval,
        wakeRefreshDelays: [Duration] = [.seconds(3), .seconds(12)]
    ) {
        self.provider = provider
        self.authenticator = authenticator
        self.refreshInterval = refreshInterval
        self.wakeRefreshDelays = wakeRefreshDelays
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
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

    func signIn() {
        guard let authenticator, signInTask == nil else { return }
        signInState = .starting
        signInTask = Task { [weak self] in
            guard let self else { return }
            do {
                let authorization = try await authenticator.beginSignIn()
                signInState = .waitingForUser(code: authorization.userCode)
                try await authenticator.completeSignIn(authorization)
                signInState = .idle
                signInTask = nil
                await refreshNow()
            } catch is CancellationError {
                signInState = .idle
                signInTask = nil
            } catch let failure as UsageFailure {
                signInState = .failed(failure)
                signInTask = nil
            } catch {
                signInState = .failed(.authentication)
                signInTask = nil
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        signInState = .idle
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        wakeTask?.cancel()
        wakeTask = Task { [weak self] in
            guard let self else { return }
            for delay in wakeRefreshDelays {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                await self.refreshNow()
            }
        }
    }
}
