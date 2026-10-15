import AppKit
import MetricsCore
import SwiftUI

struct ProcessListView: View {
    let rows: [ProcessRow]
    let limit: Int
    var placeholderRows = 0
    /// Вкладка «Процессы»: нажатие на строку копирует PID процесса в буфер обмена.
    var copiesPID = false

    @State private var copiedPID: Int32?

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<(rows.isEmpty ? placeholderRows : 0), id: \.self) { _ in
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 3)
            }
            ForEach(rows.prefix(limit)) { row in
                if copiesPID {
                    Button { copy(row.pid) } label: { rowView(row) }
                        .buttonStyle(.plain)
                        .help("Скопировать PID \(row.pid)")
                        .accessibilityHint("Копирует PID \(row.pid)")
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                } else {
                    rowView(row)
                }
            }
        }
    }

    private func rowView(_ row: ProcessRow) -> some View {
        HStack {
            // После копирования на секунду вместо имени — подтверждение с номером.
            if copiedPID == row.pid {
                Text("PID \(row.pid) скопирован").lineLimit(1)
            } else {
                Text(row.name).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Text(Format.percent(row.cpuPercent))
                .frame(width: 50, alignment: .trailing)
            Text(Format.bytes(row.memoryBytes))
                .frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 12).monospacedDigit())
        .padding(.bottom, 3)
        .overlay(alignment: .bottomLeading) { shareBar(row.cpuPercent) }
        .contentShape(Rectangle())
    }

    private func copy(_ pid: Int32) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(pid), forType: .string)
        copiedPID = pid
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if copiedPID == pid { copiedPID = nil }
        }
    }

    /// Тонкая полоска доли CPU (100 % = одно ядро), цвет — по шкале нагрева.
    private func shareBar(_ cpu: Double?) -> some View {
        let load = cpu ?? 0
        return GeometryReader { geo in
            Capsule()
                .fill(HeatScale.color(forLoad: load).swiftUIColor)
                .frame(width: geo.size.width * HeatScale.fraction(load), height: 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 2)
    }
}
