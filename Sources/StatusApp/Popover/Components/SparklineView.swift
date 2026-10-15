import Charts
import MetricsCore
import SwiftUI

struct SparklineView: View {
    let points: [HistoryPoint]
    let color: Color
    let yDomain: ClosedRange<Double>?

    init(points: [HistoryPoint], color: Color, yDomain: ClosedRange<Double>? = nil) {
        self.points = points
        self.color = color
        self.yDomain = yDomain
    }

    var body: some View {
        Chart(points, id: \.t) { point in
            LineMark(x: .value("t", point.t), y: .value("v", point.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        }
        .chartXScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .modifier(OptionalYDomain(domain: yDomain))
        .frame(height: 20)
    }
}

struct OptionalYDomain: ViewModifier {
    let domain: ClosedRange<Double>?

    func body(content: Content) -> some View {
        if let domain {
            content.chartYScale(domain: domain)
        } else {
            content.chartYScale(domain: .automatic(includesZero: false))
        }
    }
}
