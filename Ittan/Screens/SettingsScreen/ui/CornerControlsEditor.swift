import AppKit
import SwiftUI

private enum ShelfControlSlot: CaseIterable, Identifiable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    var id: Self { self }
    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }
    var accessibilityLabel: String {
        switch self {
        case .topLeading: "Top Left"
        case .topTrailing: "Top Right"
        case .bottomLeading: "Bottom Left"
        case .bottomTrailing: "Bottom Right"
        }
    }
}

private enum CornerActionZone: Equatable {
    case corner(ShelfControlSlot)
    case tray
    var usesCornerStyle: Bool { if case .corner = self { true } else { false } }
}

private struct ZoneFrame: Equatable {
    let zone: CornerActionZone
    let rect: CGRect
}

private struct ZoneFramesKey: PreferenceKey {
    static let defaultValue: [ZoneFrame] = []
    static func reduce(value: inout [ZoneFrame], nextValue: () -> [ZoneFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct CornerControlsEditor: View {
    @AppStorage(IttanPreferences.topLeadingCornerActionKey)
    private var topLeadingRaw = IttanPreferences.defaultTopLeadingCornerAction.rawValue
    @AppStorage(IttanPreferences.topTrailingCornerActionKey)
    private var topTrailingRaw = IttanPreferences.defaultTopTrailingCornerAction.rawValue
    @AppStorage(IttanPreferences.bottomLeadingCornerActionKey)
    private var bottomLeadingRaw = IttanPreferences.defaultBottomLeadingCornerAction.rawValue
    @AppStorage(IttanPreferences.bottomTrailingCornerActionKey)
    private var bottomTrailingRaw = IttanPreferences.defaultBottomTrailingCornerAction.rawValue

    @State private var dragging: ShelfCornerAction?
    @State private var dragLocation: CGPoint = .zero
    @State private var originZone: CornerActionZone?
    @State private var hoveredZone: CornerActionZone?
    @State private var zoneFrames: [ZoneFrame] = []

    private let spaceName = "cornerControlsEditor"
    private var hiddenActions: [ShelfCornerAction] {
        let visible = Set(ShelfControlSlot.allCases.map(action(at:)))
        return ShelfCornerAction.allCases.filter { $0 != .none && !visible.contains($0) }
    }
    private var placementValues: [String] {
        ShelfControlSlot.allCases.map { action(at: $0).rawValue }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Drag actions into the corners. Drop them in the tray to hide.")
                .font(.caption)
                .foregroundStyle(.secondary)
            card
            tray
            Button {
                resetToDefault()
            } label: {
                Label("Reset to Default", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .coordinateSpace(.named(spaceName))
        .onPreferenceChange(ZoneFramesKey.self) { zoneFrames = $0 }
        .overlay(alignment: .topLeading) {
            if let dragging {
                FloatingActionChip(
                    action: dragging,
                    isCorner: (hoveredZone ?? originZone)?.usesCornerStyle ?? false
                )
                .position(dragLocation)
                .allowsHitTesting(false)
                .transition(.identity)
                .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var card: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.primary.opacity(0.035))
                .overlay {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                }

            ForEach(ShelfControlSlot.allCases) { slot in
                cornerCell(slot)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: slot.alignment)
                    .padding(11)
            }
        }
        .frame(width: 210, height: 158)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: placementValues)
        .animation(.easeOut(duration: 0.18), value: hoveredZone)
    }

    private func cornerCell(_ slot: ShelfControlSlot) -> some View {
        let action = action(at: slot)
        let highlighted = hoveredZone == .corner(slot)
        let isFilled = action != .none && action != dragging
        return ZStack {
            if !isFilled {
                Circle()
                    .strokeBorder(
                        highlighted ? Color.accentColor : .primary.opacity(0.2),
                        style: StrokeStyle(
                            lineWidth: highlighted ? 2 : 1.5,
                            dash: highlighted ? [] : [4, 4]
                        )
                    )
                    .background(Circle().fill(
                        highlighted ? Color.accentColor.opacity(0.18) : .clear
                    ))
                    .scaleEffect(highlighted ? 1.12 : 1)
            }
            if action != .none {
                ActionChip(action: action, isCorner: true)
                    .opacity(action == dragging ? 0 : 1)
                    .gesture(dragGesture(for: action))
                    .help(action.title)
            }
        }
        .frame(width: 34, height: 34)
        .background(frameReporter(.corner(slot)))
        .accessibilityLabel(slot.accessibilityLabel)
        .accessibilityValue(action.title)
    }

    private var tray: some View {
        let highlighted = hoveredZone == .tray
        let visibleCount = hiddenActions.filter { $0 != dragging }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text("HIDDEN ACTIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            CornerActionFlowLayout(spacing: 8) {
                if hiddenActions.isEmpty || visibleCount == 0 {
                    Text("Drag actions here to hide them")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(hiddenActions) { action in
                    ActionChip(action: action, isCorner: false)
                        .opacity(action == dragging ? 0 : 1)
                        .gesture(dragGesture(for: action))
                        .help(action.title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.primary.opacity(highlighted ? 0.07 : 0.035)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                highlighted ? Color.accentColor : .primary.opacity(0.1),
                lineWidth: highlighted ? 2 : 1
            ))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hoveredZone)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: placementValues)
        .background(frameReporter(.tray))
    }

    private func dragGesture(for action: ShelfCornerAction) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(spaceName))
            .onChanged { value in
                if dragging == nil {
                    dragging = action
                    originZone = zone(of: action)
                    dragLocation = value.location
                    hoveredZone = originZone
                }
                dragLocation = value.location
                let resolved = resolveDrop(at: value.location) ?? originZone
                if resolved != hoveredZone {
                    withAnimation(.timingCurve(0.77, 0, 0.175, 1, duration: 0.26)) {
                        hoveredZone = resolved
                    }
                }
            }
            .onEnded { value in
                let target = resolveDrop(at: value.location) ?? originZone
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    if let target { place(action, in: target) }
                    dragging = nil
                    hoveredZone = nil
                    originZone = nil
                }
            }
    }

    private func resolveDrop(at point: CGPoint) -> CornerActionZone? {
        for frame in zoneFrames {
            if case .corner = frame.zone,
               frame.rect.insetBy(dx: -16, dy: -16).contains(point) { return frame.zone }
        }
        if let tray = zoneFrames.first(where: { $0.zone == .tray }),
           tray.rect.contains(point) { return .tray }
        return nil
    }

    private func frameReporter(_ zone: CornerActionZone) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: ZoneFramesKey.self,
                value: [ZoneFrame(zone: zone, rect: geometry.frame(in: .named(spaceName)))]
            )
        }
    }

    private func zone(of action: ShelfCornerAction) -> CornerActionZone {
        for slot in ShelfControlSlot.allCases where self.action(at: slot) == action {
            return .corner(slot)
        }
        return .tray
    }

    private func action(at slot: ShelfControlSlot) -> ShelfCornerAction {
        let raw = switch slot {
        case .topLeading: topLeadingRaw
        case .topTrailing: topTrailingRaw
        case .bottomLeading: bottomLeadingRaw
        case .bottomTrailing: bottomTrailingRaw
        }
        return ShelfCornerAction(rawValue: raw) ?? .none
    }

    private func place(_ action: ShelfCornerAction, in zone: CornerActionZone) {
        for slot in ShelfControlSlot.allCases where self.action(at: slot) == action {
            set(.none, at: slot)
        }
        if case let .corner(slot) = zone { set(action, at: slot) }
    }

    private func set(_ action: ShelfCornerAction, at slot: ShelfControlSlot) {
        switch slot {
        case .topLeading: topLeadingRaw = action.rawValue
        case .topTrailing: topTrailingRaw = action.rawValue
        case .bottomLeading: bottomLeadingRaw = action.rawValue
        case .bottomTrailing: bottomTrailingRaw = action.rawValue
        }
    }

    private func resetToDefault() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            topLeadingRaw = IttanPreferences.defaultTopLeadingCornerAction.rawValue
            topTrailingRaw = IttanPreferences.defaultTopTrailingCornerAction.rawValue
            bottomLeadingRaw = IttanPreferences.defaultBottomLeadingCornerAction.rawValue
            bottomTrailingRaw = IttanPreferences.defaultBottomTrailingCornerAction.rawValue
        }
    }
}

private struct FloatingActionChip: View {
    let action: ShelfCornerAction
    let isCorner: Bool
    private static let diameter: CGFloat = 32
    private static let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private var pillWidth: CGFloat {
        max(Self.diameter, ceil((action.title as NSString)
            .size(withAttributes: [.font: Self.font]).width) + 44)
    }
    var body: some View {
        Capsule()
            .fill(.regularMaterial)
            .frame(width: isCorner ? Self.diameter : pillWidth, height: Self.diameter)
            .overlay { chipContent(action: action, isCorner: isCorner) }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 0.5))
            .frame(width: pillWidth, height: Self.diameter)
            .shadow(color: .black.opacity(0.32), radius: 12, x: 0, y: 7)
            .scaleEffect(1.08)
    }
}

private struct ActionChip: View {
    let action: ShelfCornerAction
    let isCorner: Bool
    private static let diameter: CGFloat = 32
    private static let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private var pillWidth: CGFloat {
        max(Self.diameter, ceil((action.title as NSString)
            .size(withAttributes: [.font: Self.font]).width) + 44)
    }
    var body: some View {
        chipContent(action: action, isCorner: isCorner)
            .frame(width: isCorner ? Self.diameter : pillWidth, height: Self.diameter)
            .background(.regularMaterial, in: Capsule())
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
            .contentShape(Capsule())
            .transition(.asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .opacity
            ))
    }
}

private func chipContent(action: ShelfCornerAction, isCorner: Bool) -> some View {
    ZStack {
        Image(systemName: action.systemImage)
            .font(.system(size: 13, weight: .bold))
            .opacity(isCorner ? 1 : 0)
            .scaleEffect(isCorner ? 1 : 0.4)
            .blur(radius: isCorner ? 0 : 2)
        HStack(spacing: 6) {
            Image(systemName: action.systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(action.title)
                .font(.system(size: 12, weight: .semibold))
                .fixedSize()
        }
            .opacity(isCorner ? 0 : 1)
            .scaleEffect(isCorner ? 0.4 : 1)
            .blur(radius: isCorner ? 2 : 0)
    }
    .foregroundStyle(.primary.opacity(0.78))
}

private struct CornerActionFlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, rowHeight: CGFloat = 0, height: CGFloat = 0, rowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                height += rowHeight + spacing
                rowWidth = max(rowWidth, x - spacing)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        rowWidth = max(rowWidth, x - spacing)
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
