import Foundation
import Testing
@testable import Ittan

@Suite("Corner action migration")
struct CornerActionMigrationTests {
    @Test("The previous default corners become the current defaults once")
    func migratesPreviousDefaults() {
        let defaults = makeDefaults()
        defaults.set("clearShelf", forKey: IttanPreferences.topLeadingCornerActionKey)
        defaults.set("settings", forKey: IttanPreferences.topTrailingCornerActionKey)
        defaults.set("recentlyRemoved", forKey: IttanPreferences.bottomLeadingCornerActionKey)
        defaults.set("quickNote", forKey: IttanPreferences.bottomTrailingCornerActionKey)

        IttanPreferences.migrateCornerActions(in: defaults)

        #expect(defaults.string(forKey: IttanPreferences.topLeadingCornerActionKey) == "none")
        #expect(defaults.string(forKey: IttanPreferences.topTrailingCornerActionKey) == "quickNote")
        #expect(defaults.string(forKey: IttanPreferences.bottomLeadingCornerActionKey) == "recentlyRemoved")
        #expect(defaults.string(forKey: IttanPreferences.bottomTrailingCornerActionKey) == "none")

        defaults.set("clearShelf", forKey: IttanPreferences.topLeadingCornerActionKey)
        IttanPreferences.migrateCornerActions(in: defaults)
        #expect(defaults.string(forKey: IttanPreferences.topLeadingCornerActionKey) == "clearShelf")
    }

    @Test("A custom arrangement is kept")
    func keepsCustomArrangement() {
        let defaults = makeDefaults()
        defaults.set("paste", forKey: IttanPreferences.topLeadingCornerActionKey)
        defaults.set("addFiles", forKey: IttanPreferences.topTrailingCornerActionKey)

        IttanPreferences.migrateCornerActions(in: defaults)

        #expect(defaults.string(forKey: IttanPreferences.topLeadingCornerActionKey) == "paste")
        #expect(defaults.string(forKey: IttanPreferences.topTrailingCornerActionKey) == "addFiles")
    }

    @Test("A removed action becomes an empty corner")
    func clearsRemovedActions() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: IttanPreferences.cornerActionsMigratedKey)
        defaults.set("selectAll", forKey: IttanPreferences.bottomTrailingCornerActionKey)

        IttanPreferences.migrateCornerActions(in: defaults)

        #expect(defaults.string(forKey: IttanPreferences.bottomTrailingCornerActionKey) == "none")
    }

    private func makeDefaults() -> UserDefaults {
        let name = "ittan-corner-migration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
