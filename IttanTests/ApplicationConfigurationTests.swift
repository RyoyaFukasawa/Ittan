import Foundation
import Testing

@Suite("Application configuration")
struct ApplicationConfigurationTests {
    @Test("Launch Services prohibits duplicate Ittan processes")
    func prohibitsMultipleInstances() {
        #expect(
            Bundle.main.object(forInfoDictionaryKey: "LSMultipleInstancesProhibited") as? Bool
                == true
        )
    }
}
