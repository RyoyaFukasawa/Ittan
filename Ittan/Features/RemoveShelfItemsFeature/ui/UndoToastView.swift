import SwiftUI

struct UndoToastView: View {
    let notice: UndoNotice

    var body: some View {
        HStack(spacing: 7) {
            Text(notice.message)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 2)

            Button("Undo") {
                IttanStore.shelf.send(.undoButtonTapped)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 10)
        .frame(width: 142, height: 32)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .padding(.vertical, 1)
    }
}
