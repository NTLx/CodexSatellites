import SwiftUI

struct SettingsBarView: View {
    let launchAtLoginState: LaunchAtLoginState
    let refreshInterval: QuotaRefreshInterval
    let availableResetCount: Int?
    let onSetLaunchAtLogin: (Bool) -> Void
    let onReviewLoginItems: () -> Void
    let onAdvanceRefreshInterval: () -> Void
    let onQuit: () -> Void

    private let controlSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            launchControl
            frequencyControl
            resetCountControl
            quitControl
        }
        .padding(.horizontal, 12)
        .frame(width: 176, height: 44)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var launchControl: some View {
        switch launchAtLoginState {
        case .enabled, .disabled:
            iconButton(
                systemName: "arrow.triangle.2.circlepath",
                help: "Launch at Login",
                foreground: launchAtLoginState == .enabled ? Color.accentColor : .primary,
                active: launchAtLoginState == .enabled,
                action: { onSetLaunchAtLogin(launchAtLoginState != .enabled) }
            )
        case .requiresApproval:
            iconButton(
                systemName: "exclamationmark.triangle",
                help: "Review Login Items",
                foreground: .orange,
                action: onReviewLoginItems
            )
        case .unavailable:
            iconButton(
                systemName: "circle.slash",
                help: "Launch at Login Unavailable",
                foreground: .secondary,
                action: {}
            )
            .disabled(true)
        }
    }

    private var frequencyControl: some View {
        Button(action: onAdvanceRefreshInterval) {
            Text(refreshInterval.displayText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(width: controlSize, height: controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Circle().fill(Color.primary.opacity(0.08)))
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .help("Quota Check Frequency")
        .accessibilityLabel(Text("Quota Check Frequency"))
        .accessibilityValue(Text(refreshInterval.displayText))
    }

    private var quitControl: some View {
        iconButton(
            systemName: "power",
            help: "Quit",
            action: onQuit
        )
    }

    private var resetCountControl: some View {
        Text(availableResetCount.map(String.init) ?? "—")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .frame(width: controlSize, height: controlSize)
            .contentShape(Circle())
            .background(Circle().fill(Color.primary.opacity(0.08)))
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
            .help("Available Reset Count")
            .accessibilityLabel(Text("Available Reset Count"))
            .accessibilityValue(Text(availableResetCount.map(String.init) ?? "—"))
    }

    private func iconButton(
        systemName: String,
        help: LocalizedStringKey,
        foreground: Color = .primary,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: controlSize, height: controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(
            Circle().fill(
                active
                    ? Color.accentColor.opacity(0.14)
                    : Color.primary.opacity(0.08)
            )
        )
        .overlay {
            Circle()
                .stroke(
                    active
                        ? Color.accentColor.opacity(0.36)
                        : Color.primary.opacity(0.12),
                    lineWidth: active ? 0.75 : 0.5
                )
        }
        .help(help)
        .accessibilityLabel(Text(help))
    }
}
