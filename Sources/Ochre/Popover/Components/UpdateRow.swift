import MetricsCore
import SwiftUI

/// Строка обновления над подвалом панели. Пока обновления нет, её не видно.
struct UpdateRow: View {
    let updates: UpdateController

    var body: some View {
        switch updates.model.state {
        case .available(let version, let notesURL):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    dot
                    Text("Доступна версия \(version)").lineLimit(1)
                    Spacer(minLength: 8)
                    if let notesURL {
                        Link("Что нового", destination: notesURL)
                            .foregroundStyle(.secondary)
                            .pointerStyle(.link)
                    }
                }
                Button { updates.install() } label: {
                    Text("Установить и перезапустить")
                        .foregroundStyle(BoardPalette.inkOnWarm)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Self.accent)
                .controlSize(.large)
            }
        case .downloading(let version, let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("Скачивание \(version)")
                if let progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
            }
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Установка…")
            }
        case .checking:
            Text("Проверка обновлений…").foregroundStyle(.secondary)
        case .failed(let message):
            HStack {
                Text("Не удалось обновить").help(message)
                Spacer()
                Button("Повторить") { updates.checkNow() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        case .needsMove:
            Text("Перенесите Ochre в «Программы», чтобы получать обновления")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .idle, .upToDate:
            EmptyView()
        }
    }

    private var dot: some View {
        Circle().fill(Self.accent).frame(width: 6, height: 6)
    }

    /// Цвет шкалы на 25 % — тот же янтарь, что у плитки ядра под четвертью нагрузки.
    private static let accent = HeatScale.color(forLoad: 25).swiftUIColor
}
