import MetricsCore
import SwiftUI

struct ProcessListView: View {
    let rows: [ProcessRow]
    let limit: Int

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows.prefix(limit)) { row in
                HStack {
                    Text(row.name).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text(Format.percent(row.cpuPercent))
                        .frame(width: 50, alignment: .trailing)
                    Text(Format.bytes(row.memoryBytes))
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 12).monospacedDigit())
                .padding(.bottom, 3)
                .overlay(alignment: .bottomLeading) { shareBar(row.cpuPercent) }
            }
        }
    }

    /// Тонкая полоска доли CPU (100 % = одно ядро), цвет — по шкале нагрева.
    private func shareBar(_ cpu: Double?) -> some View {
        let load = cpu ?? 0
        return GeometryReader { geo in
            Capsule()
                .fill(HeatScale.color(forLoad: load).swiftUIColor)
                .frame(width: geo.size.width * min(max(load, 0), 100) / 100, height: 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 2)
    }
}
