import ComposableArchitecture
import Foundation

@Reducer
struct ShelfFeature {
    @ObservableState
    struct State: Equatable {
        var items: [ShelfItem]
        var history: [ShelfItem]
        var selectedIDs: Set<ShelfItem.ID> = []
        var selectionAnchor: ShelfItem.ID?
        var lastRemovedBatch: [ShelfItem] = []
        var undoNotice: UndoNotice?
        var isDropTargeted = false
        var isPanelCollapsed = false

        init(items: [ShelfItem] = [], history: [ShelfItem] = []) {
            self.items = items
            self.history = history
        }

        func dragItems(startingWith id: ShelfItem.ID) -> [ShelfItem] {
            let ids = selectedIDs.contains(id) ? selectedIDs : [id]
            return items.filter { ids.contains($0.id) && $0.exists }
        }
    }

    enum Action: Equatable {
        case addURLs([URL])
        case clearButtonTapped
        case clearHistoryButtonTapped
        case createNoteButtonTapped
        case dragOutSucceeded([ShelfItem.ID])
        case prepareDrag(ShelfItem.ID)
        case removeButtonTapped(ShelfItem.ID)
        case renameRequested(ShelfItem.ID, String)
        case restoreFromHistory(ShelfItem.ID)
        case select(ShelfItem.ID, SelectionModifiers)
        case selectAll
        case setDropTargeted(Bool)
        case setPanelCollapsed(Bool)
        case toggleLock(ShelfItem.ID)
        case undoButtonTapped
        case undoExpired(UUID)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.feedbackClient) var feedback
    @Dependency(\.noteClient) var noteClient
    @Dependency(\.shelfStorage) var storage
    @Dependency(\.uuid) var uuid

    private enum CancelID { case undoNotice }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addURLs(urls):
                guard AddShelfItems.apply(urls, to: &state.items, fileExists: storage.fileExists) else {
                    return .none
                }
                persistItems(state.items)
                return .none

            case .clearButtonTapped:
                let removable = state.items.filter { !$0.locked }
                guard !removable.isEmpty else {
                    return state.items.isEmpty ? .none : beep()
                }
                let removableIDs = Set(removable.map(\.id))
                recordInHistory(removable, state: &state)
                state.items.removeAll { removableIDs.contains($0.id) }
                state.selectedIDs.subtract(removableIDs)
                persistItems(state.items)
                return undoExpirationEffect(for: state.undoNotice)

            case .clearHistoryButtonTapped:
                state.history.removeAll()
                state.lastRemovedBatch = []
                state.undoNotice = nil
                persistHistory(state.history)
                return .cancel(id: CancelID.undoNotice)

            case .createNoteButtonTapped:
                do {
                    let url = try storage.createMarkdownNote()
                    CreateShelfNote.apply(url, to: &state.items)
                    persistItems(state.items)
                    return .run { _ in
                        await noteClient.open(url)
                    }
                } catch {
                    NSLog("Ittan: failed to create quick note: \(error.localizedDescription)")
                    return beep()
                }

            case let .dragOutSucceeded(ids):
                let ids = Set(ids)
                let removableIDs = Set(
                    state.items.filter { ids.contains($0.id) && !$0.locked }.map(\.id)
                )
                return remove(ids: removableIDs, state: &state)

            case let .prepareDrag(id):
                if !state.selectedIDs.contains(id) {
                    state.selectedIDs = [id]
                    state.selectionAnchor = id
                }
                return .none

            case let .removeButtonTapped(id):
                guard state.items.first(where: { $0.id == id })?.locked != true else {
                    return beep()
                }
                return remove(ids: [id], state: &state)

            case let .renameRequested(id, proposedName):
                do {
                    guard try RenameShelfItem.apply(
                        id: id,
                        proposedName: proposedName,
                        to: &state.items,
                        rename: storage.rename
                    ) else { return .none }
                    persistItems(state.items)
                } catch {
                    return beep()
                }
                return .none

            case let .restoreFromHistory(id):
                guard let index = state.history.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                let item = state.history[index]
                guard storage.fileExists(item.url),
                      !state.items.contains(where: { $0.path == item.path }) else { return .none }
                let dismissesUndo = state.lastRemovedBatch.contains(where: { $0.id == id })
                if dismissesUndo {
                    state.lastRemovedBatch = []
                    state.undoNotice = nil
                }
                state.history.remove(at: index)
                state.items.insert(item, at: 0)
                persistHistory(state.history)
                persistItems(state.items)
                return dismissesUndo ? .cancel(id: CancelID.undoNotice) : .none

            case let .select(id, modifiers):
                var selectedIDs = state.selectedIDs
                var selectionAnchor = state.selectionAnchor
                SelectShelfItems.apply(
                    id: id,
                    modifiers: modifiers,
                    items: state.items,
                    selectedIDs: &selectedIDs,
                    selectionAnchor: &selectionAnchor
                )
                state.selectedIDs = selectedIDs
                state.selectionAnchor = selectionAnchor
                return .none

            case .selectAll:
                var selectedIDs = state.selectedIDs
                var selectionAnchor = state.selectionAnchor
                SelectShelfItems.selectAll(
                    items: state.items,
                    selectedIDs: &selectedIDs,
                    selectionAnchor: &selectionAnchor
                )
                state.selectedIDs = selectedIDs
                state.selectionAnchor = selectionAnchor
                return .none

            case let .setDropTargeted(isTargeted):
                state.isDropTargeted = isTargeted
                return .none

            case let .setPanelCollapsed(isCollapsed):
                state.isPanelCollapsed = isCollapsed
                return .none

            case let .toggleLock(id):
                guard ToggleShelfItemLock.apply(id: id, to: &state.items) else { return .none }
                persistItems(state.items)
                return .none

            case .undoButtonTapped:
                let restorable = state.lastRemovedBatch.filter { item in
                    storage.fileExists(item.url) && !state.items.contains(where: { $0.path == item.path })
                }
                state.lastRemovedBatch = []
                state.undoNotice = nil
                guard !restorable.isEmpty else { return .cancel(id: CancelID.undoNotice) }
                let restoredIDs = Set(restorable.map(\.id))
                state.history.removeAll { restoredIDs.contains($0.id) }
                state.items.insert(contentsOf: restorable, at: 0)
                persistHistory(state.history)
                persistItems(state.items)
                return .cancel(id: CancelID.undoNotice)

            case let .undoExpired(id):
                guard state.undoNotice?.id == id else { return .none }
                state.undoNotice = nil
                state.lastRemovedBatch = []
                return .none
            }
        }
    }

    private func remove(
        ids: Set<ShelfItem.ID>,
        state: inout State
    ) -> Effect<Action> {
        var items = state.items
        var selectedIDs = state.selectedIDs
        let removed = RemoveShelfItems.apply(
            ids: ids,
            items: &items,
            selectedIDs: &selectedIDs
        )
        guard !removed.isEmpty else { return .none }
        state.items = items
        state.selectedIDs = selectedIDs
        recordInHistory(removed, state: &state)
        persistItems(state.items)
        return undoExpirationEffect(for: state.undoNotice)
    }

    private func recordInHistory(_ removed: [ShelfItem], state: inout State) {
        var history = state.history
        var lastRemovedBatch = state.lastRemovedBatch
        var undoNotice = state.undoNotice
        RemoveShelfItems.record(
            removed,
            history: &history,
            lastRemovedBatch: &lastRemovedBatch,
            undoNotice: &undoNotice,
            noticeID: uuid()
        )
        state.history = history
        state.lastRemovedBatch = lastRemovedBatch
        state.undoNotice = undoNotice
        persistHistory(state.history)
    }

    private func undoExpirationEffect(for notice: UndoNotice?) -> Effect<Action> {
        guard let notice else { return .none }
        return .run { send in
            try await clock.sleep(for: .seconds(5))
            await send(.undoExpired(notice.id))
        }
        .cancellable(id: CancelID.undoNotice, cancelInFlight: true)
    }

    private func beep() -> Effect<Action> {
        .run { _ in await feedback.beep() }
    }

    private func persistItems(_ items: [ShelfItem]) {
        do {
            try storage.saveItems(items)
        } catch {
            NSLog("Ittan: failed to persist shelf: \(error.localizedDescription)")
        }
    }

    private func persistHistory(_ history: [ShelfItem]) {
        do {
            try storage.saveHistory(history)
        } catch {
            NSLog("Ittan: failed to persist history: \(error.localizedDescription)")
        }
    }
}
