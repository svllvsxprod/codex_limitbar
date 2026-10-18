import AppKit
import SwiftUI

struct UsageMenuView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var launchAtLogin: LaunchAtLogin
    @ObservedObject var updater: AppUpdater
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let version = updater.availableVersion {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label(
                        L10n.format("update_available_format", version),
                        systemImage: "arrow.down.circle.fill"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(Color.accentColor)
            }

            if showingSettings {
                settings
            } else {
                usageContent
            }

            Divider()
            controls
        }
        .padding(18)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .buttonStyle(PanelButtonStyle())
        .task(id: showingSettings) {
            guard showingSettings else { return }
            // Menu bar panels may stay inactive when System Settings changes.
            // Read the system state while this page is visible; never re-register here.
            while !Task.isCancelled {
                launchAtLogin.refresh()
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
            }
        }
    }

    @ViewBuilder
    private var usageContent: some View {
        switch store.state {
        case let .loading(previous):
            if let previous {
                limits(snapshot: previous, isStale: true)
            } else {
                loading
            }
        case let .loaded(snapshot):
            limits(snapshot: snapshot, isStale: false)
        case let .failed(previous, failure):
            if let previous {
                limits(snapshot: previous, isStale: true)
                errorMessage(failure)
            } else {
                errorMessage(failure)
            }
        }

        if store.state.snapshot != nil, store.signInState != .idle {
            signInControls
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            LimitBarIconView(size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Codex")
                    .font(.headline)
                Text(planLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                launchAtLogin.refresh()
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(showingSettings ? Color.accentColor : Color.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Color.primary.opacity(showingSettings ? 0.09 : 0.04),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.text(showingSettings ? "back_to_limits" : "settings"))
            .accessibilityLabel(L10n.text(showingSettings ? "back_to_limits" : "settings"))
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("settings"))
                .font(.headline)

            HStack {
                Text(L10n.text("launch_at_login"))
                Spacer()
                Toggle(
                    L10n.text("launch_at_login"),
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .labelsHidden()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .frame(minHeight: 32)
            .disabled(!launchAtLogin.canChange)

            Text(launchAtLogin.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if launchAtLogin.requiresApproval {
                Button(L10n.text("open_login_items")) {
                    launchAtLogin.openSystemSettings()
                }
                .controlSize(.small)
            }

            if let message = launchAtLogin.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text(L10n.format("app_version_format", updater.version))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(L10n.text("automatic_update_checks"))
                Spacer()
                Toggle(
                    L10n.text("automatic_update_checks"),
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.setAutomaticChecks($0) }
                    )
                )
                .labelsHidden()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .frame(minHeight: 32)
            .disabled(!updater.isAvailable)

            Text(L10n.text("update_checks_description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.text("check_for_updates")) {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
            .controlSize(.small)

            Button(L10n.text("back_to_limits")) {
                showingSettings = false
            }
            .controlSize(.small)
        }
    }

    private var loading: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.text("loading_limits"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }

    private func limits(snapshot: UsageSnapshot, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                L10n.format("today_spent_format", store.dailySpentPercent),
                systemImage: "calendar"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            ForEach(snapshot.limits) { limit in
                VStack(alignment: .leading, spacing: 8) {
                    if snapshot.limits.count > 1 {
                        Text(limitName(limit))
                            .font(.subheadline.weight(.semibold))
                    }
                    ForEach(limit.windows) { window in
                        usageWindow(window)
                    }
                }
            }

            HStack {
                Label(L10n.text("available_resets"), systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.availableResetCount.map { $0.formatted() } ?? "—")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
            .help(L10n.text(snapshot.availableResetCount == nil
                ? "available_resets_unavailable" : "available_resets_description"))

            HStack(spacing: 5) {
                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.text("stale_data"))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.text("updated"))
                }
                Text(snapshot.fetchedAt, style: .relative)
                Spacer()
                if snapshot.source == .codexLimitBar {
                    Text(snapshot.source.rawValue)
                } else {
                    Button(L10n.text("independent_sign_in")) { store.signIn() }
                        .buttonStyle(.plain)
                        .disabled(store.signInState != .idle)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func usageWindow(_ window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(windowLabel(window.windowDurationMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(
                    Double(window.remainingPercent) / 100,
                    format: .percent.precision(.fractionLength(0))
                )
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color(for: window.remainingPercent))
            }
            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(color(for: window.remainingPercent))
            if let reset = window.resetsAt {
                Text(
                    L10n.format(
                        "reset_format",
                        reset.formatted(date: .abbreviated, time: .shortened)
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func errorMessage(_ failure: UsageFailure) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(failure.message, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

            if failure == .authentication || failure == .sourceUnavailable {
                signInControls
            }
        }
    }

    @ViewBuilder
    private var signInControls: some View {
        switch store.signInState {
        case .idle:
            Button(L10n.text("sign_in_chatgpt")) { store.signIn() }
                .controlSize(.small)
        case .starting:
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(L10n.text("creating_sign_in_code"))
            }
            .font(.caption)
        case let .waitingForUser(code):
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.format("code_format", code))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                Text(L10n.text("code_copied_instruction"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button(L10n.text("cancel")) { store.cancelSignIn() }
                    .controlSize(.small)
            }
        case let .failed(failure):
            VStack(alignment: .leading, spacing: 5) {
                Text(failure.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                Button(L10n.text("retry_sign_in")) { store.signIn() }
                    .controlSize(.small)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button {
                store.refresh()
            } label: {
                Label(L10n.text("refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Spacer()

            Button(L10n.text("quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .controlSize(.small)
    }

    private var planLabel: String {
        guard let plan = store.state.snapshot?.planType else {
            return L10n.text("usage_limits")
        }
        return switch plan.lowercased() {
        case "plus": "ChatGPT Plus"
        case "pro": "ChatGPT Pro"
        case "prolite": "ChatGPT Pro Lite"
        case "team": "ChatGPT Team"
        case "business": "ChatGPT Business"
        case "enterprise": "ChatGPT Enterprise"
        default: plan.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func windowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return L10n.text("window_limit") }
        switch minutes {
        case 0 ... 360:
            return L10n.format(
                "window_hours_format",
                max(1, Int(ceil(Double(minutes) / 60)))
            )
        case 9_000 ... 11_000:
            return L10n.text("window_week")
        default:
            return L10n.format("window_minutes_format", minutes)
        }
    }

    private func limitName(_ limit: UsageLimit) -> String {
        limit.id == "code-review" ? L10n.text("limit_code_review") : limit.name
    }

    private func color(for remainingPercent: Int) -> Color {
        switch remainingPercent {
        case 51 ... 100: .green
        case 21 ... 50: .orange
        default: .red
        }
    }
}
