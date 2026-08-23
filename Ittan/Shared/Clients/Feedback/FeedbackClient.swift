import AppKit
import ComposableArchitecture

struct FeedbackClient: Sendable {
    var beep: @MainActor @Sendable () -> Void
}

extension FeedbackClient: DependencyKey {
    static let liveValue = FeedbackClient {
        NSSound.beep()
    }

    static let testValue = FeedbackClient {}
}

extension DependencyValues {
    var feedbackClient: FeedbackClient {
        get { self[FeedbackClient.self] }
        set { self[FeedbackClient.self] = newValue }
    }
}
