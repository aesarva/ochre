import AppKit
import MetricsCore
import SwiftUI

enum PopoverTab: String, CaseIterable {
    case overview, cpu, memory, network, disk, sensors, processes

    var title: String {
        switch self {
        case .overview: "Обзор"
        case .cpu: "CPU"
        case .memory: "Память"
        case .network: "Сеть"
        case .disk: "Диск"
        case .sensors: "Сенсоры"
        case .processes: "Процессы"
        }
    }
}

struct PopoverView: View {
    let store: MetricsStore
    let onOpenSettings: () -> Void
    @State private var tab: PopoverTab

    init(store: MetricsStore, initialTab: PopoverTab, onOpenSettings: @escaping () -> Void) {
        self.store = store
        self.onOpenSettings = onOpenSettings
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 12) {
            GlassTabBar(selection: $tab)

            content

            Divider().opacity(0.5)
            HStack {
                Button("Настройки", action: onOpenSettings)
                Spacer()
                Button("Выход") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 340)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .overview: OverviewTab(store: store) { tab = .cpu }
        case .cpu: CPUTab(store: store)
        case .memory: MemoryTab(store: store)
        case .network: NetworkTab(store: store)
        case .disk: DiskTab(store: store)
        case .sensors: SensorsTab(store: store)
        case .processes: ProcessesTab(store: store)
        }
    }
}
