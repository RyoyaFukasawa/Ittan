import AppKit

struct DragSnapshot: Equatable {
    let leftMouseButtonDown: Bool
    let pasteboardChangeCount: Int
    let containsSupportedContent: Bool
    let internalDragActive: Bool
}

enum DragTransition: Equatable {
    case none
    case started
    case ended
}

struct DragStateMachine {
    private(set) var lastChangeCount: Int
    private(set) var isDragActive = false

    init(initialChangeCount: Int) {
        self.lastChangeCount = initialChangeCount
    }

    mutating func update(_ snapshot: DragSnapshot) -> DragTransition {
        if isDragActive {
            guard !snapshot.leftMouseButtonDown else { return .none }
            isDragActive = false
            lastChangeCount = snapshot.pasteboardChangeCount
            return .ended
        }

        guard snapshot.leftMouseButtonDown else {
            lastChangeCount = snapshot.pasteboardChangeCount
            return .none
        }

        guard snapshot.pasteboardChangeCount != lastChangeCount,
              snapshot.containsSupportedContent,
              !snapshot.internalDragActive else {
            return .none
        }

        lastChangeCount = snapshot.pasteboardChangeCount
        isDragActive = true
        return .started
    }
}

@MainActor
final class DragMonitor {
    var isInternalDragActive = false

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var stateMachine: DragStateMachine
    private var timer: Timer?
    private let onDragStarted: () -> Void
    private let onDragEnded: () -> Void

    init(onDragStarted: @escaping () -> Void, onDragEnded: @escaping () -> Void) {
        stateMachine = DragStateMachine(
            initialChangeCount: NSPasteboard(name: .drag).changeCount
        )
        self.onDragStarted = onDragStarted
        self.onDragEnded = onDragEnded
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let snapshot = DragSnapshot(
            leftMouseButtonDown: (NSEvent.pressedMouseButtons & 1) != 0,
            pasteboardChangeCount: dragPasteboard.changeCount,
            containsSupportedContent: PasteboardImporter.canImport(dragPasteboard),
            internalDragActive: isInternalDragActive
        )

        switch stateMachine.update(snapshot) {
        case .started:
            onDragStarted()
        case .ended:
            onDragEnded()
        case .none:
            break
        }
    }
}
