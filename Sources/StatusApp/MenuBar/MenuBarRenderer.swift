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
            case .icon:
                let attachment = NSTextAttachment()
                let image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)
                image?.isTemplate = true
                attachment.image = image
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
