import Testing
@testable import Ittan

@Suite("Drag state machine")
struct DragStateMachineTests {
    @Test("Three quick horizontal reversals trigger a shake")
    func detectsShake() {
        var detector = CursorShakeDetector()

        let results = [
            detector.update(point: .init(x: 0, y: 0), time: 0),
            detector.update(point: .init(x: 32, y: 1), time: 0.08),
            detector.update(point: .init(x: -2, y: 0), time: 0.16),
            detector.update(point: .init(x: 32, y: 1), time: 0.24),
            detector.update(point: .init(x: -2, y: 0), time: 0.32),
        ]
        #expect(results == [false, false, false, false, true])
    }

    @Test("Small cursor jitter does not trigger a shake")
    func ignoresJitter() {
        var detector = CursorShakeDetector()
        let points = [0.0, 4, -3, 5, -2, 3, -4]

        for (index, x) in points.enumerated() {
            let triggered = detector.update(
                point: .init(x: x, y: 0),
                time: Double(index) * 0.05
            )
            #expect(!triggered)
        }
    }

    @Test("Slow reversals do not combine into a shake")
    func ignoresSlowReversals() {
        var detector = CursorShakeDetector()
        let samples: [(Double, Double)] = [
            (0, 0), (32, 0.1), (-2, 0.5), (32, 0.9), (-2, 1.3),
        ]

        for (x, time) in samples {
            let triggered = detector.update(point: .init(x: x, y: 0), time: time)
            #expect(!triggered)
        }
    }

    @Test("A changed supported-content drag starts and mouse release ends")
    func startAndEnd() {
        var machine = DragStateMachine(initialChangeCount: 10)

        #expect(machine.update(snapshot(down: true, count: 11, file: true)) == .started)
        #expect(machine.update(snapshot(down: true, count: 11, file: true)) == .none)
        #expect(machine.update(snapshot(down: false, count: 11, file: true)) == .ended)
    }

    @Test("Ordinary mouse movement does not start a drag")
    func ignoresOrdinaryMouseMovement() {
        var machine = DragStateMachine(initialChangeCount: 10)
        #expect(machine.update(snapshot(down: true, count: 10, file: false)) == .none)
    }

    @Test("A browser URL drag starts")
    func startsForBrowserURL() {
        var machine = DragStateMachine(initialChangeCount: 4)
        #expect(machine.update(snapshot(down: true, count: 5, file: true)) == .started)
    }

    @Test("Ittan's own drag is ignored")
    func ignoresInternalDrag() {
        var machine = DragStateMachine(initialChangeCount: 10)
        #expect(machine.update(snapshot(down: true, count: 11, file: true, internalDrag: true)) == .none)
    }

    private func snapshot(
        down: Bool,
        count: Int,
        file: Bool,
        internalDrag: Bool = false
    ) -> DragSnapshot {
        DragSnapshot(
            leftMouseButtonDown: down,
            pasteboardChangeCount: count,
            containsSupportedContent: file,
            internalDragActive: internalDrag
        )
    }
}
