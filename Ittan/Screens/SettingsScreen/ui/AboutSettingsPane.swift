import SwiftUI

struct AboutSettingsPane: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Ittan").font(.title.bold())
            Text("A temporary shelf for your Mac.").foregroundStyle(.secondary)
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
