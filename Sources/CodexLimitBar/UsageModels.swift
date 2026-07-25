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
            "Не найдена сессия ChatGPT"
        case .authentication:
            "Сессия ChatGPT истекла. Выполните автономный вход."
        case .forbidden:
            "У аккаунта нет доступа к данным лимитов Codex"
        case .rateLimited:
            "OpenAI временно ограничил обновления"
        case .vpnUnavailable:
            "VPN не обнаружен. OpenAI-запрос заблокирован."
        case .network:
            "Не удалось подключиться к OpenAI"
        case .malformedResponse:
            "OpenAI вернул неизвестный формат лимитов"
        }
    }
}

protocol CodexUsageProviding: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}
