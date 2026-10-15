import MetricsCore
import SwiftUI

struct TileView: View {
    let title: String
    let value: String
    let highlighted: Bool
    let points: [HistoryPoint]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(highlighted ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            SparklineView(points: points, color: highlighted ? .red : color)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
