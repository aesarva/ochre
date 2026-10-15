import MetricsCore
import SwiftUI

struct ProcessesTab: View {
    enum SortOrder: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Память"
    }

    let store: MetricsStore
    @State private var order: SortOrder = .cpu

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $order) {
                ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if let rows = store.latest?.processes, !rows.isEmpty {
                ScrollView {
                    ProcessListView(rows: sorted(rows), limit: 50, copiesPID: true)
                }
                .frame(maxHeight: 360)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func sorted(_ rows: [ProcessRow]) -> [ProcessRow] {
        switch order {
        case .cpu: rows.sorted { ($0.cpuPercent ?? -1) > ($1.cpuPercent ?? -1) }
        case .memory: rows.sorted { $0.memoryBytes > $1.memoryBytes }
        }
    }
}
