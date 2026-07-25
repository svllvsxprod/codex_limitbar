import Foundation

struct LocalChatGPTAuth: Sendable {
    let accessToken: String
    let accountID: String
    let source: UsageSource
}

struct LocalChatGPTAuthLoader: Sendable {
    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func load() throws -> LocalChatGPTAuth {
        do {
            if let auth = try loadCodexAuth(
                at: homeDirectory.appending(path: ".codex/auth.json")
            ) {
                return auth
            }
        } catch {}

        do {
            if let auth = try loadOpenCodeAuth(
                at: homeDirectory.appending(path: ".local/share/opencode/auth.json")
            ) {
                return auth
            }
        } catch {}

        throw UsageFailure.sourceUnavailable
    }

    private func loadCodexAuth(at url: URL) throws -> LocalChatGPTAuth? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        try validatePrivatePermissions(at: url)

        let file = try JSONDecoder().decode(
            CodexAuthFile.self,
            from: Data(contentsOf: url, options: .mappedIfSafe)
        )
        guard
            let token = file.tokens?.accessToken.nilIfEmpty,
            let accountID = file.tokens?.accountID.nilIfEmpty
        else {
            return nil
        }
        return LocalChatGPTAuth(
            accessToken: token,
            accountID: accountID,
            source: .codexCLI
        )
    }

    private func loadOpenCodeAuth(at url: URL) throws -> LocalChatGPTAuth? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        try validatePrivatePermissions(at: url)

        let file = try JSONDecoder().decode(
            OpenCodeAuthFile.self,
            from: Data(contentsOf: url, options: .mappedIfSafe)
        )
        guard
            let token = file.openai?.access.nilIfEmpty,
            let accountID = file.openai?.accountID.nilIfEmpty
        else {
            return nil
        }
        return LocalChatGPTAuth(
            accessToken: token,
            accountID: accountID,
            source: .openCode
        )
    }

    private func validatePrivatePermissions(at url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard
            let permissions = attributes[.posixPermissions] as? NSNumber,
            permissions.intValue & 0o077 == 0
        else {
            throw UsageFailure.sourceUnavailable
        }
    }
}

private struct CodexAuthFile: Decodable {
    let tokens: Tokens?

    struct Tokens: Decodable {
        let accessToken: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }
}

private struct OpenCodeAuthFile: Decodable {
    let openai: OpenAIAuth?

    struct OpenAIAuth: Decodable {
        let access: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case access
            case accountID = "accountId"
        }
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
