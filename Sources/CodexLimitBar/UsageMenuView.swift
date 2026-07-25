import AppKit
import SwiftUI

struct UsageMenuView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

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

            Divider()
            controls
        }
        .padding(16)
        .frame(width: 330)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { store.start() }
        .onDisappear { store.stop() }
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
        }
    }

    private var loading: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Получаю лимиты...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }

    private func limits(snapshot: UsageSnapshot, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(snapshot.limits) { limit in
                VStack(alignment: .leading, spacing: 8) {
                    if snapshot.limits.count > 1 {
                        Text(limit.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    ForEach(limit.windows) { window in
                        usageWindow(window)
                    }
                }
            }

            HStack(spacing: 5) {
                if isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Показаны последние данные")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Обновлено")
                }
                Text(snapshot.fetchedAt, style: .relative)
                Spacer()
                if snapshot.source == .codexLimitBar {
                    Text(snapshot.source.rawValue)
                } else {
                    Button("Автономный вход") { store.signIn() }
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
                Text("\(window.remainingPercent)%")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color(for: window.remainingPercent))
            }
            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(color(for: window.remainingPercent))
            if let reset = window.resetsAt {
                Text("Сброс: \(reset.formatted(date: .abbreviated, time: .shortened))")
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
            Button("Войти в ChatGPT") { store.signIn() }
                .controlSize(.small)
        case .starting:
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text("Создаю код входа...")
            }
            .font(.caption)
        case let .waitingForUser(code):
            VStack(alignment: .leading, spacing: 5) {
                Text("Код: \(code)")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .textSelection(.enabled)
                Text("Код скопирован. Завершите вход в открывшемся браузере.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Отменить") { store.cancelSignIn() }
                    .controlSize(.small)
            }
        case let .failed(failure):
            VStack(alignment: .leading, spacing: 5) {
                Text(failure.message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                Button("Повторить вход") { store.signIn() }
                    .controlSize(.small)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button {
                store.refresh()
            } label: {
                Label("Обновить", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)

            Spacer()

            Button("Выход") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .controlSize(.small)
    }

    private var planLabel: String {
        guard let plan = store.state.snapshot?.planType else {
            return "Лимиты использования"
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
        guard let minutes else { return "Лимит" }
        switch minutes {
        case 0 ... 360:
            return "\(max(1, Int(ceil(Double(minutes) / 60)))) ч"
        case 9_000 ... 11_000:
            return "Неделя"
        default:
            return "\(minutes) мин"
        }
    }

    private func color(for remainingPercent: Int) -> Color {
        switch remainingPercent {
        case 51 ... 100: .green
        case 21 ... 50: .orange
        default: .red
        }
    }
}
