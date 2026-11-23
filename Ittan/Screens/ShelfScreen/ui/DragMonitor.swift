import AppKit

struct CursorShakeDetector {
    private let minimumExcursion: CGFloat = 24
    private let maximumTurnInterval: TimeInterval = 0.22
    private let requiredReversals = 3

    private var lastPoint: CGPoint?
    private var segmentDistance: CGFloat = 0
    private var segmentDirection: CGFloat = 0
    private var reversalCount = 0
    private var lastReversalTime: TimeInterval?

    mutating func reset(at point: CGPoint? = nil) {
        lastPoint = point
        segmentDistance = 0
        segmentDirection = 0
        reversalCount = 0
        lastReversalTime = nil
    }

    mutating func update(point: CGPoint, time: TimeInterval) -> Bool {
        guard let lastPoint else {
            self.lastPoint = point
            return false
        }
        self.lastPoint = point

        let deltaX = point.x - lastPoint.x
        let deltaY = point.y - lastPoint.y
        guard abs(deltaX) >= 2, abs(deltaX) >= abs(deltaY) else { return false }

        let direction: CGFloat = deltaX > 0 ? 1 : -1
        guard segmentDirection != 0 else {
            segmentDirection = direction
            segmentDistance = deltaX
            return false
        }

        if direction == segmentDirection {
            segmentDistance += deltaX
            return false
        }

        let completedExcursion = abs(segmentDistance)
        segmentDirection = direction
        segmentDistance = deltaX
        guard completedExcursion >= minimumExcursion else { return false }

        if let lastReversalTime,
           time - lastReversalTime <= maximumTurnInterval {
            reversalCount += 1
        } else {
            reversalCount = 1
        }
        lastReversalTime = time

        guard reversalCount >= requiredReversals else { return false }
        reset(at: point)
        return true
    }
}

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
    private var shakeDetector = CursorShakeDetector()
    private var didTriggerShake = false
    private var timer: Timer?
    private let onDragStarted: () -> Void
    private let onDragMoved: () -> Void
    private let onDragShaken: () -> Void
    private let onDragEnded: () -> Void

    init(
        onDragStarted: @escaping () -> Void,
        onDragMoved: @escaping () -> Void = {},
        onDragShaken: @escaping () -> Void = {},
        onDragEnded: @escaping () -> Void
    ) {
        stateMachine = DragStateMachine(
            initialChangeCount: NSPasteboard(name: .drag).changeCount
        )
        self.onDragStarted = onDragStarted
        self.onDragMoved = onDragMoved
        self.onDragShaken = onDragShaken
        self.onDragEnded = onDragEnded
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
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
            shakeDetector.reset(at: NSEvent.mouseLocation)
            didTriggerShake = false
            onDragStarted()
        case .ended:
            shakeDetector.reset()
            didTriggerShake = false
            onDragEnded()
        case .none:
            if stateMachine.isDragActive {
                if !didTriggerShake,
                   shakeDetector.update(
                       point: NSEvent.mouseLocation,
                       time: ProcessInfo.processInfo.systemUptime
                   ) {
                    didTriggerShake = true
                    onDragShaken()
                }
                onDragMoved()
            }
            break
        }
    }
}
