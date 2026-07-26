import Foundation

struct UsageWindow: Equatable, Sendable, Identifiable {
    let usedPercent: Int
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    var id: String {
        "\(windowDurationMinutes ?? -1)-\(resetsAt?.timeIntervalSince1970 ?? -1)"
    }

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

struct UsageLimit: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let windows: [UsageWindow]
}

enum UsageSource: String, Equatable, Sendable {
    case codexLimitBar = "Codex Limit Bar"
    case codexCLI = "Codex CLI"
    case openCode = "OpenCode"
}

struct UsageSnapshot: Equatable, Sendable {
    let limits: [UsageLimit]
    let planType: String?
    let fetchedAt: Date
    let source: UsageSource

    var lowestRemainingPercent: Int? {
        limits.flatMap(\.windows).map(\.remainingPercent).min()
    }
}

enum UsageFailure: Error, Equatable, Sendable {
    case sourceUnavailable
    case authentication
    case forbidden
    case rateLimited
    case vpnUnavailable
    case network
    case malformedResponse

    var message: String {
        switch self {
        case .sourceUnavailable:
            L10n.text("failure_source_unavailable")
        case .authentication:
            L10n.text("failure_authentication")
        case .forbidden:
            L10n.text("failure_forbidden")
        case .rateLimited:
            L10n.text("failure_rate_limited")
        case .vpnUnavailable:
            L10n.text("failure_vpn_unavailable")
        case .network:
            L10n.text("failure_network")
        case .malformedResponse:
            L10n.text("failure_malformed_response")
        }
    }
}

protocol CodexUsageProviding: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}
