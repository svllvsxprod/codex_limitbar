import AppKit
import Foundation
import Security

struct ChatGPTDeviceAuthorization: Sendable {
    let deviceAuthID: String
    let userCode: String
    let interval: TimeInterval
}

protocol ChatGPTAuthSessionProviding: Sendable {
    func validAuth(forceRefresh: Bool) async throws -> LocalChatGPTAuth
}

protocol ChatGPTAuthenticating: Sendable {
    func beginSignIn() async throws -> ChatGPTDeviceAuthorization
    func completeSignIn(_ authorization: ChatGPTDeviceAuthorization) async throws
}

struct StoredOAuthCredential: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let accountID: String

    var localAuth: LocalChatGPTAuth {
        LocalChatGPTAuth(
            accessToken: accessToken,
            accountID: accountID,
            source: .codexLimitBar
        )
    }
}

struct KeychainOAuthCredentialStore: Sendable {
    private let service = "local.svllvsx.codex-limitbar.oauth"
    private let account = "openai"

    func load() throws -> StoredOAuthCredential? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecUseDataProtectionKeychain: true,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ] as CFDictionary,
            &result
        )

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw UsageFailure.authentication
        }

        do {
            return try JSONDecoder().decode(StoredOAuthCredential.self, from: data)
        } catch {
            throw UsageFailure.authentication
        }
    }

    func save(_ credential: StoredOAuthCredential) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(credential)
        } catch {
            throw UsageFailure.authentication
        }

        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ] as CFDictionary
        let updateStatus = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw UsageFailure.authentication
        }

        let addStatus = SecItemAdd(
            [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecUseDataProtectionKeychain: true,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecValueData: data
            ] as CFDictionary,
            nil
        )
        guard addStatus == errSecSuccess else {
            throw UsageFailure.authentication
        }
    }
}

actor ChatGPTAuthManager: ChatGPTAuthSessionProviding, ChatGPTAuthenticating {
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let issuer = URL(string: "https://auth.openai.com")!
    private static let devicePage = URL(string: "https://auth.openai.com/codex/device")!

    private let externalAuthLoader: LocalChatGPTAuthLoader
    private let credentialStore: KeychainOAuthCredentialStore
    private let requestGate: any OpenAIRequestGating
    private let session: URLSession

    init(
        externalAuthLoader: LocalChatGPTAuthLoader = LocalChatGPTAuthLoader(),
        credentialStore: KeychainOAuthCredentialStore = KeychainOAuthCredentialStore(),
        requestGate: any OpenAIRequestGating = PublicServiceConnectivityGate()
    ) {
        self.externalAuthLoader = externalAuthLoader
        self.credentialStore = credentialStore
        self.requestGate = requestGate
        self.session = Self.makeSession()
    }

    func validAuth(forceRefresh: Bool) async throws -> LocalChatGPTAuth {
        if let credential = try credentialStore.load() {
            let expiresSoon = credential.expiresAt.timeIntervalSinceNow <= 60
            if forceRefresh || expiresSoon {
                return try await refresh(credential).localAuth
            }
            return credential.localAuth
        }
        return try externalAuthLoader.load()
    }

    func beginSignIn() async throws -> ChatGPTDeviceAuthorization {
        guard await requestGate.allowsOpenAIRequest() else {
            throw UsageFailure.vpnUnavailable
        }

        var request = URLRequest(url: Self.issuer.appending(path: "api/accounts/deviceauth/usercode"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("codex_limitbar/0.1.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(DeviceCodeRequest(clientID: Self.clientID))

        let response: DeviceCodeResponse = try await send(request)
        let authorization = ChatGPTDeviceAuthorization(
            deviceAuthID: response.deviceAuthID,
            userCode: response.userCode,
            interval: max(TimeInterval(response.interval) ?? 5, 1) + 3
        )

        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(authorization.userCode, forType: .string)
            NSWorkspace.shared.open(Self.devicePage)
        }
        return authorization
    }

    func completeSignIn(_ authorization: ChatGPTDeviceAuthorization) async throws {
        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try Task.checkCancellation()
            var request = URLRequest(url: Self.issuer.appending(path: "api/accounts/deviceauth/token"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("codex_limitbar/0.1.1", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONEncoder().encode(
                DeviceTokenRequest(
                    deviceAuthID: authorization.deviceAuthID,
                    userCode: authorization.userCode
                )
            )

            let data: Data
            let response: HTTPURLResponse
            (data, response) = try await performRequest(for: request)
            if response.statusCode == 200 {
                let exchange = try JSONDecoder().decode(DeviceTokenResponse.self, from: data)
                let credential = try await exchangeCode(
                    code: exchange.authorizationCode,
                    verifier: exchange.codeVerifier
                )
                try credentialStore.save(credential)
                return
            }
            guard response.statusCode == 403 || response.statusCode == 404 else {
                throw UsageFailure.authentication
            }
            try await Task.sleep(for: .seconds(authorization.interval))
        }
        throw UsageFailure.authentication
    }

    private func refresh(_ credential: StoredOAuthCredential) async throws -> StoredOAuthCredential {
        var request = URLRequest(url: Self.issuer.appending(path: "oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("codex_limitbar/0.1.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = formBody([
            "grant_type": "refresh_token",
            "refresh_token": credential.refreshToken,
            "client_id": Self.clientID
        ])

        let tokens: OAuthTokenResponse = try await send(request)
        let next = try makeCredential(tokens: tokens, fallbackAccountID: credential.accountID)
        try credentialStore.save(next)
        return next
    }

    private func exchangeCode(code: String, verifier: String) async throws -> StoredOAuthCredential {
        var request = URLRequest(url: Self.issuer.appending(path: "oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("codex_limitbar/0.1.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = formBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.issuer.appending(path: "deviceauth/callback").absoluteString,
            "client_id": Self.clientID,
            "code_verifier": verifier
        ])

        let tokens: OAuthTokenResponse = try await send(request)
        return try makeCredential(tokens: tokens, fallbackAccountID: nil)
    }

    private func makeCredential(
        tokens: OAuthTokenResponse,
        fallbackAccountID: String?
    ) throws -> StoredOAuthCredential {
        guard
            let access = tokens.accessToken.nilIfEmpty,
            let refresh = tokens.refreshToken.nilIfEmpty,
            let accountID = extractAccountID(from: tokens) ?? fallbackAccountID
        else {
            throw UsageFailure.authentication
        }
        return StoredOAuthCredential(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokens.expiresIn ?? 3600)),
            accountID: accountID
        )
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: HTTPURLResponse
        (data, response) = try await performRequest(for: request)
        guard 200 ..< 300 ~= response.statusCode else {
            throw UsageFailure.authentication
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw UsageFailure.authentication
        }
    }

    private func performRequest(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UsageFailure.network
            }
            return (data, httpResponse)
        } catch let failure as UsageFailure {
            throw failure
        } catch {
            throw UsageFailure.network
        }
    }

    private func formBody(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.map(URLQueryItem.init(name:value:))
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private func extractAccountID(from tokens: OAuthTokenResponse) -> String? {
        for token in [tokens.idToken, tokens.accessToken] {
            guard let token, let claims = JWTClaims(token: token) else { continue }
            if let accountID = claims.accountID { return accountID }
        }
        return nil
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }
}

private struct DeviceCodeRequest: Encodable {
    let clientID: String

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
    }
}

private struct DeviceCodeResponse: Decodable {
    let deviceAuthID: String
    let userCode: String
    let interval: String

    enum CodingKeys: String, CodingKey {
        case deviceAuthID = "device_auth_id"
        case userCode = "user_code"
        case interval
    }
}

private struct DeviceTokenRequest: Encodable {
    let deviceAuthID: String
    let userCode: String

    enum CodingKeys: String, CodingKey {
        case deviceAuthID = "device_auth_id"
        case userCode = "user_code"
    }
}

private struct DeviceTokenResponse: Decodable {
    let authorizationCode: String
    let codeVerifier: String

    enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorization_code"
        case codeVerifier = "code_verifier"
    }
}

private struct OAuthTokenResponse: Decodable {
    let idToken: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct JWTClaims: Decodable {
    let rootAccountID: String?
    let organizations: [Organization]?
    let openAIAuth: OpenAIAuth?

    var accountID: String? {
        rootAccountID ?? openAIAuth?.accountID ?? organizations?.first?.id
    }

    init?(token: String) {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var encoded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard
            let data = Data(base64Encoded: encoded),
            let claims = try? JSONDecoder().decode(JWTClaims.self, from: data)
        else {
            return nil
        }
        self = claims
    }

    struct Organization: Decodable {
        let id: String
    }

    struct OpenAIAuth: Decodable {
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accountID = "chatgpt_account_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case rootAccountID = "chatgpt_account_id"
        case organizations
        case openAIAuth = "https://api.openai.com/auth"
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let self, !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return self
    }
}
