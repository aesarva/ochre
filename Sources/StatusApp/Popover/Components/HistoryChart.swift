import Charts
import MetricsCore
import SwiftUI

struct HistoryChart: View {
    let title: String
    let points: [HistoryPoint]
    let color: Color
    let yDomain: ClosedRange<Double>?
    let valueLabel: (Double) -> String

    init(title: String, points: [HistoryPoint], color: Color, yDomain: ClosedRange<Double>?,
         valueLabel: @escaping (Double) -> String) {
        self.title = title
        self.points = points
        self.color = color
        self.yDomain = yDomain
        self.valueLabel = valueLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Chart(points, id: \.t) { point in
                AreaMark(x: .value("t", point.t), y: .value("v", point.value))
                    .foregroundStyle(color.opacity(0.18))
                LineMark(x: .value("t", point.t), y: .value("v", point.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .chartXScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(valueLabel(v)).font(.system(size: 9))
                        }
                    }
                }
            }
            .modifier(OptionalYDomain(domain: yDomain))
            .frame(height: 80)
        }
    }
}
