import SwiftUI

struct SettingsBarView: View {
    let launchAtLoginState: LaunchAtLoginState
    let onSetLaunchAtLogin: (Bool) -> Void
    let onReviewLoginItems: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Launch at Login")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 0)

            launchControl

            Divider()
                .frame(height: 18)

            Button(action: onQuit) {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit")
        }
        .padding(.horizontal, 12)
        .frame(width: 240, height: 44)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    @ViewBuilder
    private var launchControl: some View {
        switch launchAtLoginState {
        case .enabled, .disabled:
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { launchAtLoginState == .enabled },
                    set: onSetLaunchAtLogin
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .accessibilityLabel("Launch at Login")
        case .requiresApproval:
            Button("Review…", action: onReviewLoginItems)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Review Login Items")
        case .unavailable:
            Text("—")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Launch at Login unavailable")
        }
    }
}
