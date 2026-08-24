import SwiftUI

struct BehaviorSettingsPane: View {
    @AppStorage(IttanPreferences.shelfSideKey) private var shelfSideRaw = ShelfSide.left.rawValue
    @AppStorage(IttanPreferences.expandsForExternalDragKey) private var expandsForDrag = true
    @AppStorage(IttanPreferences.removesAfterDragKey) private var removesAfterDrag = true
    @AppStorage(IttanPreferences.historyLimitKey) private var historyLimit = 50

    private var shelfSide: Binding<ShelfSide> {
        Binding(
            get: { ShelfSide(rawValue: shelfSideRaw) ?? .left },
            set: { shelfSideRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("Shelf") {
                Picker("Screen edge", selection: shelfSide) {
                    ForEach(ShelfSide.allCases) { side in Text(side.title).tag(side) }
                }

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
        }
        .settingsFormStyle()
        .onChange(of: shelfSideRaw) { _, _ in
            NotificationCenter.default.post(name: .ittanPreferencesDidChange, object: nil)
        }
        .onChange(of: historyLimit) { _, _ in
            NotificationCenter.default.post(name: .ittanPreferencesDidChange, object: nil)
        }
    }
}
