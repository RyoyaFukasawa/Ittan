import ServiceManagement
import SwiftUI

struct GeneralSettingsPane: View {
    @State private var launchesAtLogin = false
    @State private var requiresApproval = false
    @State private var launchError: String?
    @State private var isRefreshingStatus = false

    var body: some View {
        Form {
            Section("System") {
                Toggle(isOn: $launchesAtLogin) {
                    SettingLabel(
                        "Launch at Login",
                        description: "Start Ittan automatically when you sign in."
                    )
                }
                .toggleStyle(.switch)
                .onChange(of: launchesAtLogin) { _, enabled in
                    guard !isRefreshingStatus else { return }
                    updateLaunchAtLogin(enabled)
                }

                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                } else if requiresApproval {
                    Text("Approve Ittan in System Settings → General → Login Items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .settingsFormStyle()
        .onAppear { refreshStatus() }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            launchError = nil
            try LaunchAtLogin.setEnabled(enabled)
        } catch {
            launchError = "Could not update Launch at Login: \(error.localizedDescription)"
        }
        refreshStatus()
    }

    private func refreshStatus() {
        isRefreshingStatus = true
        launchesAtLogin = SMAppService.mainApp.status == .enabled
        requiresApproval = SMAppService.mainApp.status == .requiresApproval
        DispatchQueue.main.async { isRefreshingStatus = false }
    }
}

@MainActor
private enum LaunchAtLogin {
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard SMAppService.mainApp.status != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status != .notRegistered else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
