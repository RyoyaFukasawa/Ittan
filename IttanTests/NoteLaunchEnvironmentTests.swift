import Testing
@testable import Ittan

@Suite("Quick note launch environment")
struct NoteLaunchEnvironmentTests {
    @Test("Electron node mode is not forwarded to the editor")
    func removesElectronNodeMode() {
        let environment = NoteLaunchEnvironment.make(from: [
            "ELECTRON_RUN_AS_NODE": "1",
            "ELECTRON_NO_ASAR": "1",
            "ELECTRON_NO_ATTACH_CONSOLE": "1",
            "HOME": "/Users/example",
            "PATH": "/usr/bin",
        ])

        #expect(environment["ELECTRON_RUN_AS_NODE"] == nil)
        #expect(environment["ELECTRON_NO_ASAR"] == nil)
        #expect(environment["ELECTRON_NO_ATTACH_CONSOLE"] == nil)
        #expect(environment["HOME"] == "/Users/example")
        #expect(environment["PATH"] == "/usr/bin")
    }
}
