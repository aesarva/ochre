import MetricsCore
import SwiftUI

/// Тихая строка метрики: название, монохромный мини-график за 10 минут, значение.
struct MetricRow: View {
    let title: String
    let value: String
    let points: [HistoryPoint]
    var highlighted = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            SparklineView(points: points, color: highlighted ? .heatHot : Color.primary.opacity(0.55))
                .frame(width: 90)
            Spacer(minLength: 6)
            Text(value)
                .foregroundStyle(highlighted ? Color.heatHot : .primary)
                .lineLimit(1)
        }
        .font(.system(size: 12).monospacedDigit())
    }
}
