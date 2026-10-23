import MetricsCore
import SwiftUI

/// Строка обновления над подвалом панели. Пока обновления нет, её не видно.
struct UpdateRow: View {
    let updates: UpdateController

    var body: some View {
        switch updates.model.state {
        case .available(let version, let notesURL):
            HStack(spacing: 6) {
                dot
                Text("Доступна версия \(version)")
                if let notesURL {
                    Link("Что нового", destination: notesURL)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button("Установить и перезапустить") { updates.install() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
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
        case .idle, .upToDate:
            EmptyView()
        }
    }

    private var dot: some View {
        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
    }
}
