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
            }
        }
    }
}
