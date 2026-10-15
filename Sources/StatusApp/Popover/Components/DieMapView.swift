import MetricsCore
import SwiftUI

/// Карта кристалла: кластеры ядер CPU и полоса GPU в стеклянной линзе, цвет — по нагрузке.
struct DieMapView: View {
    enum Size { case compact, large }

    let cpu: CPUStats?
    let gpu: GPUStats?
    let cpuCelsius: Double?
    let size: Size
    var temperatureHighlighted = false
    var onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let onTap {
            Button(action: onTap) { lens }
                .buttonStyle(.plain)
                .accessibilityLabel("Карта кристалла")
                .accessibilityHint("Открывает вкладку CPU")
        } else {
            lens
        }
    }

    private var lens: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(clusters.enumerated()), id: \.element.cluster.level) { position, item in
                    clusterView(item.cluster, cores: item.cores, isFirst: position == 0)
                }
                if let gpu { gpuView(gpu) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .contentShape(Rectangle())
    }

    private var clusters: [(cluster: ClusterLoad, cores: [CoreLoad])] {
        guard let cpu else { return [] }
        return cpu.clusters.sorted { $0.level < $1.level }.map { cluster in
            (cluster, cpu.cores.filter { $0.level == cluster.level }.sorted { $0.index < $1.index })
        }
    }

    private func clusterView(_ cluster: ClusterLoad, cores: [CoreLoad], isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(cluster.name).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                if isFirst {
                    Text(Format.celsius(cpuCelsius))
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(temperatureHighlighted ? Color.heatHot : .primary)
                }
            }
            // Большие кластеры (Ultra) переносятся на несколько рядов по ≤ 12 ячеек.
            ForEach(DieMapRows.split(count: cores.count), id: \.lowerBound) { range in
                HStack(spacing: 3) {
                    ForEach(cores[range], id: \.index) { core in
                        coreCell(core, clusterName: cluster.name, height: cellHeight(level: cluster.level))
                    }
                }
            }
        }
    }

    private func cellHeight(level: Int) -> CGFloat {
        switch size {
        case .large: 28
        case .compact: level == 0 ? 22 : 16
        }
    }

    private func coreCell(_ core: CoreLoad, clusterName: String, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(HeatScale.color(forLoad: core.percent).swiftUIColor)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.primary.opacity(0.1))
            }
            .overlay {
                if size == .large {
                    Text(Format.integer(core.percent))
                        .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.8))
                }
            }
            .frame(height: height)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: core.percent)
            .help("Ядро \(core.index + 1) · \(clusterName) · \(Format.percent(core.percent))")
    }

    private func gpuView(_ gpu: GPUStats) -> some View {
        let total = GPUBars.displayCount(coreCount: gpu.coreCount)
        let lit = GPUBars.litCount(utilization: gpu.utilizationPercent, total: total)
        // Горящие полоски при малой загрузке не «холодные», а просто светлее фона — иначе их не видно.
        let litColor = gpu.utilizationPercent >= 20
            ? HeatScale.color(forLoad: gpu.utilizationPercent).swiftUIColor
            : Color.primary.opacity(0.5)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("GPU").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(Format.percent(gpu.utilizationPercent))
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 2) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < lit ? litColor : HeatColor.cold.swiftUIColor)
                        .frame(height: 9)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: lit)
            .help("GPU · \(gpu.coreCount ?? total) ядер · \(Format.percent(gpu.utilizationPercent))")
        }
    }
}
