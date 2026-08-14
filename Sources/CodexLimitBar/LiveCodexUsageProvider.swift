import Foundation

struct LiveCodexUsageProvider: CodexUsageProviding {
    private let authSession: any ChatGPTAuthSessionProviding
    private let requestGate: any OpenAIRequestGating
    private let session: URLSession

    init(
        authSession: any ChatGPTAuthSessionProviding = ChatGPTAuthManager(),
        requestGate: any OpenAIRequestGating = PublicServiceConnectivityGate(),
        session: URLSession = LiveCodexUsageProvider.makeSession()
    ) {
        self.authSession = authSession
        self.requestGate = requestGate
        self.session = session
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard await requestGate.allowsOpenAIRequest() else {
            throw UsageFailure.vpnUnavailable
        }

        return try await AuthenticationRetry.once(
            operation: { try await fetchWithCurrentAuth(forceRefresh: false) },
            retryOperation: { try await fetchWithCurrentAuth(forceRefresh: true) }
        )
    }

    private func fetchWithCurrentAuth(forceRefresh: Bool) async throws -> UsageSnapshot {
        let auth = try await authSession.validAuth(forceRefresh: forceRefresh)
        var request = URLRequest(
            url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!
        )
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("codex_limitbar/0.3.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageFailure.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageFailure.network
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return try BackendUsageParser.parse(
                data: data,
                source: auth.source,
                fetchedAt: Date()
            )
        case 401:
            throw UsageFailure.authentication
        case 403:
            throw UsageFailure.forbidden
        case 429:
            throw UsageFailure.rateLimited
        default:
            throw UsageFailure.network
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }
}

enum AuthenticationRetry {
    static func once<Value: Sendable>(
        delay: Duration = .seconds(1),
        operation: @escaping @Sendable () async throws -> Value,
        retryOperation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation()
        } catch let failure as UsageFailure where failure == .authentication {
            try await Task.sleep(for: delay)
            return try await retryOperation()
        }
    }
}

enum BackendUsageParser {
    static func parse(
        data: Data,
        source: UsageSource,
        fetchedAt: Date
    ) throws -> UsageSnapshot {
        let response: BackendUsageResponse
        do {
            response = try JSONDecoder().decode(BackendUsageResponse.self, from: data)
        } catch {
            throw UsageFailure.malformedResponse
        }

        var limits: [UsageLimit] = []
        if let limit = makeLimit(id: "codex", name: "Codex", details: response.rateLimit) {
            limits.append(limit)
        }
        if let limit = makeLimit(
            id: "code-review",
            name: "Code review",
            details: response.codeReviewRateLimit
        ) {
            limits.append(limit)
        }
        limits.append(contentsOf: response.additionalRateLimits.compactMap { item in
            makeLimit(
                id: item.meteredFeature,
                name: item.limitName,
                details: item.rateLimit
            )
        })

        guard !limits.isEmpty else {
            throw UsageFailure.malformedResponse
        }

        return UsageSnapshot(
            limits: limits,
            planType: response.planType,
            fetchedAt: fetchedAt,
            source: source
        )
    }

    private static func makeLimit(
        id: String,
        name: String,
        details: BackendRateLimitDetails?
    ) -> UsageLimit? {
        guard let details else { return nil }
        let windows = [details.primaryWindow, details.secondaryWindow]
            .compactMap(makeWindow)
        guard !windows.isEmpty else { return nil }
        return UsageLimit(id: id, name: name, windows: windows)
    }

    private static func makeWindow(_ window: BackendRateLimitWindow?) -> UsageWindow? {
        guard let window else { return nil }
        let duration = window.limitWindowSeconds.map { seconds in
            max(1, Int(ceil(Double(seconds) / 60)))
        }
        let reset = window.resetAt.map { Date(timeIntervalSince1970: Double($0)) }
        return UsageWindow(
            usedPercent: max(0, min(100, window.usedPercent)),
            windowDurationMinutes: duration,
            resetsAt: reset
        )
    }
}

private struct BackendUsageResponse: Decodable {
    let planType: String?
    let rateLimit: BackendRateLimitDetails?
    let codeReviewRateLimit: BackendRateLimitDetails?
    let additionalRateLimits: [BackendAdditionalRateLimit]

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case codeReviewRateLimit = "code_review_rate_limit"
        case additionalRateLimits = "additional_rate_limits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        rateLimit = try container.decodeIfPresent(BackendRateLimitDetails.self, forKey: .rateLimit)
        codeReviewRateLimit = try container.decodeIfPresent(
            BackendRateLimitDetails.self,
            forKey: .codeReviewRateLimit
        )
        additionalRateLimits = try container.decodeIfPresent(
            [BackendAdditionalRateLimit].self,
            forKey: .additionalRateLimits
        ) ?? []
    }
}

private struct BackendAdditionalRateLimit: Decodable {
    let limitName: String
    let meteredFeature: String
    let rateLimit: BackendRateLimitDetails?

    enum CodingKeys: String, CodingKey {
        case limitName = "limit_name"
        case meteredFeature = "metered_feature"
        case rateLimit = "rate_limit"
    }
}

private struct BackendRateLimitDetails: Decodable {
    let primaryWindow: BackendRateLimitWindow?
    let secondaryWindow: BackendRateLimitWindow?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct BackendRateLimitWindow: Decodable {
    let usedPercent: Int
    let limitWindowSeconds: Int?
    let resetAt: Int64?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAt = "reset_at"
    }
}
