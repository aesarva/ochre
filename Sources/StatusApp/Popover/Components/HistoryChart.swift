import Charts
import MetricsCore
import SwiftUI

/// Монохромный график за 10 минут: линия с мягкой заливкой, без сетки, подписи оси справа.
struct HistoryChart: View {
    let title: String
    let value: String
    let points: [HistoryPoint]
    let yDomain: ClosedRange<Double>?
    let valueLabel: (Double) -> String
    var highlighted = false

    var body: some View {
        let tint = highlighted ? Color.heatHot : Color.primary
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(value).foregroundStyle(highlighted ? Color.heatHot : .primary)
            }
            .font(.system(size: 12).monospacedDigit())
            Chart(points, id: \.t) { point in
                AreaMark(x: .value("t", point.t), y: .value("v", point.value))
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("t", point.t), y: .value("v", point.value))
                    .foregroundStyle(tint.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.4, lineJoin: .round))
            }
            .chartXScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .chartYAxis {
                if let yDomain {
                    AxisMarks(position: .trailing,
                              values: [yDomain.lowerBound, (yDomain.lowerBound + yDomain.upperBound) / 2, yDomain.upperBound]) {
                        label($0)
                    }
                } else {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { label($0) }
                }
            }
            .modifier(OptionalYDomain(domain: yDomain))
            .frame(height: 70)
        }
    }

    private func label(_ value: AxisValue) -> some AxisMark {
        AxisValueLabel {
            if let v = value.as(Double.self) {
                Text(valueLabel(v)).font(.system(size: 9).monospacedDigit()).foregroundStyle(.tertiary)
            }
        }
    }
}
