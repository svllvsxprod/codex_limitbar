import Foundation

enum L10n {
    static func text(_ key: String, languageCode: String? = nil) -> String {
        bundle(for: languageCode).localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: arguments)
    }

    private static func bundle(for languageCode: String?) -> Bundle {
        let resources = Bundle.main.bundleIdentifier == "local.svllvsx.codex-limitbar"
            ? Bundle.main
            : Bundle.module
        guard
            let languageCode,
            let path = resources.path(forResource: languageCode, ofType: "lproj"),
            let languageBundle = Bundle(path: path)
        else {
            return resources
        }
        return languageBundle
    }
}
