import SwiftUI

/// Стеклянная капсула вкладок: пять основных сегментов и меню «Ещё» для «Сенсоров» и «Процессов».
struct GlassTabBar: View {
    @Binding var selection: PopoverTab
    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let primary: [PopoverTab] = [.overview, .cpu, .memory, .network, .disk]
    private static let more: [PopoverTab] = [.sensors, .processes]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.primary, id: \.self) { tab in
                segment(tab.title, selected: selection == tab) { select(tab) }
            }
            moreMenu
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }

    private var moreMenu: some View {
        let selectedMore = Self.more.contains(selection)
        return Menu {
            ForEach(Self.more, id: \.self) { tab in
                Button(tab.title) { select(tab) }
            }
        } label: {
            HStack(spacing: 3) {
                Text("Ещё")
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .modifier(SegmentLabel(selected: selectedMore, namespace: highlight))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).modifier(SegmentLabel(selected: selected, namespace: highlight))
        }
        .buttonStyle(.plain)
    }

    private func select(_ tab: PopoverTab) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { selection = tab }
    }
}

private struct SegmentLabel: ViewModifier {
    let selected: Bool
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        // Ширина резервируется под полужирное начертание, чтобы выбор вкладки не сдвигал соседние.
        content
            .font(.system(size: 12, weight: .semibold))
            .hidden()
            .overlay {
                content
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background {
                if selected {
                    Capsule().fill(Color.primary.opacity(0.12))
                        .matchedGeometryEffect(id: "selected", in: namespace)
                }
            }
            .contentShape(Capsule())
    }
}
