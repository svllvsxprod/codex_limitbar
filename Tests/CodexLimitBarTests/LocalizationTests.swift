import XCTest
@testable import CodexLimitBar

final class LocalizationTests: XCTestCase {
    func testSelectsEnglishAndRussianTranslations() {
        XCTAssertEqual(L10n.text("refresh", languageCode: "en"), "Refresh")
        XCTAssertEqual(L10n.text("refresh", languageCode: "ru"), "Обновить")
        XCTAssertEqual(
            L10n.text("failure_authentication", languageCode: "en"),
            "Your ChatGPT session expired. Use independent sign-in."
        )
        XCTAssertEqual(
            L10n.text("failure_authentication", languageCode: "ru"),
            "Сессия ChatGPT истекла. Выполните автономный вход."
        )
    }

    func testSystemPreferenceSelectsSupportedLanguage() {
        let localizations = ["en", "ru"]

        XCTAssertEqual(
            Bundle.preferredLocalizations(from: localizations, forPreferences: ["en-US"]).first,
            "en"
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(from: localizations, forPreferences: ["ru-RU"]).first,
            "ru"
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(from: localizations, forPreferences: ["de-DE"]).first,
            "en"
        )
    }

    func testEverySupportedLanguageContainsEveryString() {
        let keys = [
            "app_name",
            "menu_bar_accessibility_format",
            "today_spent_format",
            "usage_limits",
            "loading_limits",
            "stale_data",
            "updated",
            "independent_sign_in",
            "window_limit",
            "window_hours_format",
            "window_week",
            "window_minutes_format",
            "reset_format",
            "sign_in_chatgpt",
            "creating_sign_in_code",
            "code_format",
            "code_copied_instruction",
            "cancel",
            "retry_sign_in",
            "refresh",
            "quit",
            "settings",
            "update_available_format",
            "app_version_format",
            "automatic_update_checks",
            "update_checks_description",
            "check_for_updates",
            "launch_at_login_prompt_title",
            "launch_at_login_prompt_description",
            "launch_at_login_enable",
            "launch_at_login_later",
            "ok",
            "back_to_limits",
            "launch_at_login",
            "launch_at_login_description",
            "launch_at_login_enabled",
            "launch_at_login_approval",
            "launch_at_login_install",
            "launch_at_login_unavailable",
            "open_login_items",
            "launch_at_login_error_format",
            "limit_code_review",
            "failure_source_unavailable",
            "failure_authentication",
            "failure_forbidden",
            "failure_rate_limited",
            "failure_vpn_unavailable",
            "failure_network",
            "failure_malformed_response"
        ]

        for language in ["en", "ru"] {
            for key in keys {
                XCTAssertNotEqual(L10n.text(key, languageCode: language), key)
            }
        }
    }
}
