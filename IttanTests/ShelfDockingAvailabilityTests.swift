import CoreGraphics
import Testing
@testable import Ittan

@Suite("Shelf docking availability")
struct ShelfDockingAvailabilityTests {
    @Test("A persisted dock becomes an expanded floating shelf while docking is disabled")
    func disablesPersistedDock() {
        let placement = ShelfDockingAvailability.activePlacement(.docked(
            screenID: "screen",
            edge: .right,
            normalizedMidY: 0.6,
            isCollapsed: true,
            order: 0
        ))
        #expect(placement == .floating(
            screenID: "screen",
            normalizedFrame: CGRect(x: 0.77, y: 0.35, width: 0.2, height: 0.5)
        ))
    }
}
