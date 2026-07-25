import Foundation

protocol OpenAIRequestGating: Sendable {
    func allowsOpenAIRequest() async -> Bool
}

struct PublicServiceConnectivityGate: OpenAIRequestGating {
    typealias Probe = @Sendable (URL) async -> Bool

    static let defaultEndpoints = [
        URL(string: "https://www.youtube.com/generate_204")!,
        URL(string: "https://www.speedtest.net/")!,
        URL(string: "https://www.whatsapp.com/")!
    ]

    private let endpoints: [URL]
    private let probe: Probe

    init() {
        let session = Self.makeSession()
        self.init { url in
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 5
            )
            request.httpMethod = "HEAD"
            request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
            do {
                let (_, response) = try await session.data(for: request)
                return response is HTTPURLResponse
            } catch {
                return false
            }
        }
    }

    init(
        endpoints: [URL] = PublicServiceConnectivityGate.defaultEndpoints,
        probe: @escaping Probe
    ) {
        self.endpoints = endpoints
        self.probe = probe
    }

    func allowsOpenAIRequest() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            for endpoint in endpoints {
                group.addTask { await probe(endpoint) }
            }

            for await isReachable in group where isReachable {
                group.cancelAll()
                return true
            }
            return false
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 6
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }
}
