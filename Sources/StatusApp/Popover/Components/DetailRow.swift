import SwiftUI

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(valueColor).monospacedDigit()
        }
        .font(.system(size: 12))
    }
}
