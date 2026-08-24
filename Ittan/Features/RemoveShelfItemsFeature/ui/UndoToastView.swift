import SwiftUI

struct UndoToastView: View {
    let notice: UndoNotice
    @State private var remainingFraction: CGFloat = 1

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
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay {
            ZStack {
                Capsule()
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)

                CapsuleCountdownBorder()
                    .trim(from: 1 - remainingFraction, to: 1)
                    .stroke(
                        Color.accentColor.opacity(0.78),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .padding(0.5)
            }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .padding(.vertical, 1)
        .task(id: notice.id) {
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                remainingFraction = 1
            }
            await Task.yield()
            withAnimation(.linear(duration: 5)) {
                remainingFraction = 0
            }
        }
    }
}

private struct CapsuleCountdownBorder: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.height / 2
        let curve = radius * 0.552_284_75
        let rightCenterX = rect.maxX - radius
        let leftCenterX = rect.minX + radius
        let centerY = rect.midY
        var path = Path()
        path.move(to: CGPoint(x: leftCenterX, y: rect.minY))
        path.addLine(to: CGPoint(x: rightCenterX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: centerY),
            control1: CGPoint(x: rightCenterX + curve, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: centerY - curve)
        )
        path.addCurve(
            to: CGPoint(x: rightCenterX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: centerY + curve),
            control2: CGPoint(x: rightCenterX + curve, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: leftCenterX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: centerY),
            control1: CGPoint(x: leftCenterX - curve, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: centerY + curve)
        )
        path.addCurve(
            to: CGPoint(x: leftCenterX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: centerY - curve),
            control2: CGPoint(x: leftCenterX - curve, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
