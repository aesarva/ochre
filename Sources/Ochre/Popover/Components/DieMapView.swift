import MetricsCore
import SwiftUI

/// Карта кристалла: графитовое табло в стеклянной линзе — ядра CPU флажками с загрузкой и полоса GPU.
struct DieMapView: View {
    let cpu: CPUStats?
    let gpu: GPUStats?
    let cpuCelsius: Double?
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
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(clusters.enumerated()), id: \.element.cluster.level) { position, item in
                    clusterView(item.cluster, cores: item.cores, isFirst: position == 0)
                }
                if let gpu { gpuView(gpu) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BoardPalette.board, in: .rect(cornerRadius: 13, style: .continuous))
            .padding(5)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
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
            HStack(alignment: .firstTextBaseline) {
                Text(cluster.name.uppercased()).font(BoardPalette.font(11)).tracking(0.8)
                    .foregroundStyle(BoardPalette.inkDim)
                Spacer()
                if isFirst {
                    Text(Format.celsius(cpuCelsius))
                        .font(BoardPalette.font(15))
                        .foregroundStyle(temperatureHighlighted ? Color.heatHot : BoardPalette.ink)
                }
            }
            // Большие кластеры (Ultra) переносятся на несколько рядов по ≤ 12 ячеек.
            ForEach(DieMapRows.split(count: cores.count), id: \.lowerBound) { range in
                HStack(spacing: 3) {
                    ForEach(cores[range], id: \.index) { core in
                        coreCell(core, clusterName: cluster.name, level: cluster.level)
                    }
                }
            }
        }
    }

    /// Высота флажка и кегль цифры: старший кластер крупнее. Одинаково на «Обзоре» и CPU —
    /// иначе блок меняет высоту при переключении вкладок.
    private func cellMetrics(level: Int) -> (height: CGFloat, font: CGFloat) {
        level == 0 ? (34, 16) : (26, 12)
    }

    private func coreCell(_ core: CoreLoad, clusterName: String, level: Int) -> some View {
        let metrics = cellMetrics(level: level)
        return FlapTile(value: Format.integer(core.percent), load: core.percent, fontSize: metrics.font)
            .frame(height: metrics.height)
            .help("Ядро \(core.index + 1) · \(clusterName) · \(Format.percent(core.percent))")
    }

    private func gpuView(_ gpu: GPUStats) -> some View {
        let total = GPUBars.displayCount(coreCount: gpu.coreCount)
        let lit = GPUBars.litCount(utilization: gpu.utilizationPercent, total: total)
        // Горящие полоски при малой загрузке не «холодные», а просто светлее фона — иначе их не видно.
        let litColor = gpu.utilizationPercent >= 20
            ? HeatScale.color(forLoad: gpu.utilizationPercent).swiftUIColor
            : BoardPalette.inkDim
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("GPU").font(BoardPalette.font(11)).tracking(0.8).foregroundStyle(BoardPalette.inkDim)
                Spacer()
                Text(Format.percent(gpu.utilizationPercent))
                    .font(BoardPalette.font(11)).foregroundStyle(BoardPalette.inkDim)
            }
            HStack(spacing: 2) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < lit ? litColor : BoardPalette.flap)
                        .frame(height: 9)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: lit)
            .help("GPU · \(gpu.coreCount ?? total) ядер · \(Format.percent(gpu.utilizationPercent))")
        }
    }
}
