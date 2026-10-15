import AppKit
import MetricsCore
import SwiftUI

/// Debug aid: renders every popover tab and the menu-bar title to PNGs without needing Screen Recording access.
@MainActor
enum SnapshotExporter {
    static func export(to directory: String, store: MetricsStore, settings: SettingsStore) {
        let dir = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for tab in PopoverTab.allCases {
            let view = PopoverView(store: store, initialTab: tab, onOpenSettings: {})
                .background(Color(nsColor: .windowBackgroundColor))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let cg = renderer.cgImage {
                write(cg, to: dir.appendingPathComponent("tab-\(tab.rawValue).png"))
            }
        }
        let cpu = store.latest.map { store.history.points(.cpuTotal, now: $0.uptime).map(\.value) } ?? []
        let segments = MenuBarContent.segments(items: settings.settings.menuBarItems, snapshot: store.latest,
                                               cpuHistory: cpu, active: store.activeAlerts)
        let title = MenuBarRenderer.attributedTitle(segments)
        let size = title.size()
        let image = NSImage(size: NSSize(width: ceil(size.width) + 16, height: 28), flipped: false) { rect in
            NSColor.windowBackgroundColor.setFill()
            rect.fill()
            title.draw(at: NSPoint(x: 8, y: (rect.height - size.height) / 2))
            return true
        }
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("menubar.png"))
        }
    }

    private static func write(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
