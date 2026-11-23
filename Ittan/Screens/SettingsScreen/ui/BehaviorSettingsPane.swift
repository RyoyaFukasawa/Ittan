import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BehaviorSettingsPane: View {
    @AppStorage(IttanPreferences.expandsForExternalDragKey) private var expandsForDrag = true
    @AppStorage(IttanPreferences.removesAfterDragKey) private var removesAfterDrag = true
    @AppStorage(IttanPreferences.historyLimitKey) private var historyLimit = 50
    @AppStorage(IttanPreferences.shelfEdgeKey) private var edgeRaw = ShelfEdge.right.rawValue

    var body: some View {
        Form {
            Section("Position") {
                Picker("Edge", selection: $edgeRaw) {
                    Text("Left").tag(ShelfEdge.left.rawValue)
                    Text("Right").tag(ShelfEdge.right.rawValue)
                }
                .pickerStyle(.segmented)
            }

            Section("Shelf") {
                Toggle(isOn: $expandsForDrag) {
                    SettingLabel(
                        "Expand when dragging",
                        description: "Temporarily reveal Ittan when a drag starts elsewhere."
                    )
                }
                .toggleStyle(.switch)

                Toggle(isOn: $removesAfterDrag) {
                    SettingLabel(
                        "Remove after a successful drag",
                        description: "Remove unlocked items after dropping them into another app."
                    )
                }
                .toggleStyle(.switch)
            }

            Section("Recently Removed") {
                Picker("Keep", selection: $historyLimit) {
                    ForEach([10, 25, 50, 100], id: \.self) { count in
                        Text("\(count) items").tag(count)
                    }
                }
            }

            Section("Quick Note") {
                QuickNoteAppPicker()
            }

            Section("Shelf Corners") {
                CornerControlsEditor()
            }
        }
        .settingsFormStyle()
        .onChange(of: historyLimit) { _, _ in
            NotificationCenter.default.post(name: .ittanPreferencesDidChange, object: nil)
        }
        .onChange(of: edgeRaw) { _, _ in postAppearanceChange() }
    }

    private func postAppearanceChange() {
        NotificationCenter.default.post(name: .ittanShelfAppearanceDidChange, object: nil)
    }

}

private struct QuickNoteAppChoice: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let icon: NSImage

    var id: String { bundleID }
}

private struct QuickNoteAppPicker: View {
    @AppStorage(IttanPreferences.quickNoteApplicationBundleIDKey) private var bundleID = ""
    @State private var apps: [QuickNoteAppChoice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Open with", selection: $bundleID) {
                Text("Default").tag("")
                ForEach(displayedApps) { app in
                    Label {
                        Text(app.name)
                    } icon: {
                        Image(nsImage: app.icon)
                    }
                    .tag(app.bundleID)
                }
            }
            Button("Choose Application…", action: chooseApplication)
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
        .onAppear(perform: reload)
    }

    private var displayedApps: [QuickNoteAppChoice] {
        guard !bundleID.isEmpty, !apps.contains(where: { $0.bundleID == bundleID }) else { return apps }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return apps
        }
        return apps + [choice(for: url, bundleID: bundleID)].compactMap { $0 }
    }

    private func reload() {
        let contentType = UTType(filenameExtension: "md") ?? .plainText
        var seen = Set<String>()
        apps = NSWorkspace.shared.urlsForApplications(toOpen: contentType).compactMap { url in
            guard let identifier = Bundle(url: url)?.bundleIdentifier, seen.insert(identifier).inserted else {
                return nil
            }
            return choice(for: url, bundleID: identifier)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func choice(for url: URL, bundleID: String) -> QuickNoteAppChoice? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        return QuickNoteAppChoice(
            bundleID: bundleID,
            name: FileManager.default.displayName(atPath: url.path),
            icon: icon
        )
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Open Quick Notes With"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let identifier = Bundle(url: url)?.bundleIdentifier else { return }
        if !apps.contains(where: { $0.bundleID == identifier }),
           let chosen = choice(for: url, bundleID: identifier) {
            apps.append(chosen)
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        bundleID = identifier
    }
}
