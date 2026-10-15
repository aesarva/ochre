import AppKit
import MetricsCore
import SwiftUI

enum PopoverTab: String, CaseIterable {
    case overview, cpu, memory, network, disk, sensors, processes

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .network: "network"
        case .disk: "internaldrive"
        case .sensors: "thermometer.medium"
        case .processes: "list.bullet"
        }
    }

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
        VStack(spacing: 10) {
            Picker("", selection: $tab) {
                ForEach(PopoverTab.allCases, id: \.self) { item in
                    Image(systemName: item.symbol).help(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            content

            Divider()
            HStack {
                Button("⚙ Настройки", action: onOpenSettings)
                Spacer()
                Button("Выход") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding(12)
        .frame(width: 360)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .overview: OverviewTab(store: store)
        case .cpu: CPUTab(store: store)
        case .memory: MemoryTab(store: store)
        case .network: NetworkTab(store: store)
        case .disk: DiskTab(store: store)
        case .sensors: SensorsTab(store: store)
        case .processes: ProcessesTab(store: store)
        }
    }
}
