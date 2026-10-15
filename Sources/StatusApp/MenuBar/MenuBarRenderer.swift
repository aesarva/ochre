import AppKit
import MetricsCore

enum MenuBarRenderer {
    @MainActor
    static func attributedTitle(_ segments: [MenuBarSegment]) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let result = NSMutableAttributedString()
        for (index, segment) in segments.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }
            switch segment {
            case .miniDie(let cells):
                let attachment = NSTextAttachment()
                if cells.isEmpty {
                    let image = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
                    image?.isTemplate = true
                    attachment.image = image
                } else {
                    let image = miniDieImage(cells)
                    attachment.image = image
                    // Центрируем сетку относительно строки текста.
                    attachment.bounds = NSRect(x: 0, y: (font.capHeight - image.size.height) / 2,
                                               width: image.size.width, height: image.size.height)
                }
                result.append(NSAttributedString(attachment: attachment))
            case .cpuGraph(let values):
                let attachment = NSTextAttachment()
                attachment.image = graphImage(values)
                result.append(NSAttributedString(attachment: attachment))
            case .text(let text, let highlighted):
                let color: NSColor = highlighted ? .systemRed : .labelColor
                result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
            }
        }
        return result
    }

    /// Значок строки меню как картинка (прозрачный фон) — для предпросмотра в настройках и снимков.
    @MainActor
    static func image(_ segments: [MenuBarSegment]) -> NSImage {
        let title = attributedTitle(segments)
        let size = title.size()
        return NSImage(size: NSSize(width: ceil(size.width), height: max(ceil(size.height), 16)), flipped: false) { rect in
            title.draw(at: NSPoint(x: 0, y: (rect.height - size.height) / 2))
            return true
        }
    }

    /// Сетка ядер 4×4 pt с промежутком 1.5 pt; холодные ячейки — системным цветом текста, нагретые — шкалой.
    @MainActor
    private static func miniDieImage(_ cells: [MiniDieCell]) -> NSImage {
        let cell: CGFloat = 4, gap: CGFloat = 1.5
        let rows = (cells.map(\.row).max() ?? 0) + 1
        let columns = (cells.map(\.column).max() ?? 0) + 1
        let size = NSSize(width: CGFloat(columns) * (cell + gap) - gap, height: CGFloat(rows) * (cell + gap) - gap)
        return NSImage(size: size, flipped: true) { _ in
            for c in cells {
                switch HeatScale.color(forLoad: c.load) {
                case .cold: NSColor.labelColor.withAlphaComponent(0.35).setFill()
                case let .rgb(r, g, b): NSColor(srgbRed: r, green: g, blue: b, alpha: 1).setFill()
                }
                let rect = NSRect(x: CGFloat(c.column) * (cell + gap), y: CGFloat(c.row) * (cell + gap),
                                  width: cell, height: cell)
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
    }

    @MainActor
    private static func graphImage(_ values: [Double]) -> NSImage {
        let size = NSSize(width: 34, height: 14)
        let bars = Array(values.suffix(10))
        return NSImage(size: size, flipped: false) { _ in
            NSColor.labelColor.setFill()
            let offset = 10 - bars.count
            for (i, value) in bars.enumerated() {
                let clamped = min(max(value, 0), 100)
                let height = max(1, CGFloat(clamped) / 100 * size.height)
                NSBezierPath(rect: NSRect(x: CGFloat(offset + i) * 3.4, y: 0, width: 3, height: height)).fill()
            }
            return true
        }
    }
}
