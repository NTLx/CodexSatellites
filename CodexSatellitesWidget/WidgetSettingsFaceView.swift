import AppIntents
import SwiftUI

struct WidgetSettingsFaceView: View {
    let entry: CodexWidgetEntry
    let family: WidgetPresentationFamily

    private let controlSize: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: "Settings")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                backButton
            }

            Spacer(minLength: 8)

            controls
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var controls: some View {
        switch family {
        case .small:
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .center,
                spacing: 10
            ) {
                launchControl
                frequencyControl
                resetCountControl
                quitControl
            }
        case .medium:
            HStack(spacing: 18) {
                Spacer(minLength: 0)
                launchControl
                frequencyControl
                resetCountControl
                quitControl
                Spacer(minLength: 0)
            }
        }
    }

    private var backButton: some View {
        Button(intent: SetWidgetFaceIntent(family: family, face: .quota)) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(Circle().fill(Color.primary.opacity(0.08)))
        .overlay {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .accessibilityLabel(Text(verbatim: "Back to quota"))
        .accessibilityHint(Text(verbatim: "Returns this widget to the quota view."))
    }

    @ViewBuilder
    private var launchControl: some View {
        switch launchState {
        case .enabled:
            actionButton(
                action: .toggleLaunchAtLogin,
                systemName: "arrow.triangle.2.circlepath",
                label: "Launch at Login",
                hint: "Turns off Launch at Login.",
                foreground: .accentColor,
                active: true
            )
            .accessibilityValue(Text(verbatim: "On"))
        case .disabled:
            actionButton(
                action: .toggleLaunchAtLogin,
                systemName: "arrow.triangle.2.circlepath",
                label: "Launch at Login",
                hint: "Turns on Launch at Login."
            )
            .accessibilityValue(Text(verbatim: "Off"))
        case .requiresApproval:
            actionButton(
                action: .reviewLoginItems,
                systemName: "exclamationmark.triangle",
                label: "Review Login Items",
                hint: "Opens System Settings to review Launch at Login.",
                foreground: .orange
            )
        case .unavailable:
            Image(systemName: "circle.slash")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: controlSize, height: controlSize)
                .foregroundStyle(.secondary)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay {
                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
                .accessibilityLabel(Text(verbatim: "Launch at Login Unavailable"))
        }
    }

    private var frequencyControl: some View {
        Button(intent: WidgetSettingsActionIntent(action: .advanceRefreshInterval)) {
            Text(verbatim: refreshIntervalText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(width: controlSize, height: controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Circle().fill(Color.primary.opacity(0.08)))
        .overlay {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .accessibilityLabel(Text(verbatim: "Quota Check Frequency"))
        .accessibilityValue(Text(verbatim: refreshIntervalText))
        .accessibilityHint(Text(verbatim: "Cycles between 1, 5, and 15 minutes."))
    }

    private var resetCountControl: some View {
        Text(verbatim: settingsSnapshot?.availableResetCount.map(String.init) ?? "—")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .frame(width: controlSize, height: controlSize)
            .background(Circle().fill(Color.primary.opacity(0.08)))
            .overlay {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityLabel(Text(verbatim: "Available Reset Count"))
            .accessibilityValue(Text(verbatim: settingsSnapshot?.availableResetCount.map(String.init) ?? "—"))
    }

    private var quitControl: some View {
        actionButton(
            action: .quit,
            systemName: "power",
            label: "Quit",
            hint: "Quits CodexSatellites without changing Launch at Login."
        )
    }

    private func actionButton(
        action: WidgetSettingsAction,
        systemName: String,
        label: String,
        hint: String,
        foreground: Color = .primary,
        active: Bool = false
    ) -> some View {
        Button(intent: WidgetSettingsActionIntent(action: action)) {
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
            Circle().stroke(
                active
                    ? Color.accentColor.opacity(0.36)
                    : Color.primary.opacity(0.12),
                lineWidth: active ? 0.75 : 0.5
            )
        }
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityHint(Text(verbatim: hint))
    }

    private var settingsSnapshot: WidgetSettingsSnapshot? {
        entry.settingsSnapshot
    }

    private var launchState: WidgetLaunchAtLoginState {
        settingsSnapshot?.launchAtLoginState ?? .unavailable
    }

    private var refreshIntervalText: String {
        guard let minutes = settingsSnapshot?.refreshIntervalMinutes,
              [1, 5, 15].contains(minutes) else {
            return "—"
        }
        return "\(minutes)m"
    }
}
