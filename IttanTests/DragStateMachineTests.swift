import Testing
@testable import Ittan

@Suite("Drag state machine")
struct DragStateMachineTests {
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
