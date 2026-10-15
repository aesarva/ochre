import AppKit
import MetricsCore
import SwiftUI

/// Debug aid: renders every popover tab and the menu-bar title to PNGs without needing Screen Recording access.
@MainActor
enum SnapshotExporter {
    static func export(to directory: String, store: MetricsStore, settings: SettingsStore) {
        let dir = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Стекло и меню рисует AppKit, поэтому снимаем настоящий hosting view на цветной «обоине».
        for tab in PopoverTab.allCases {
            let view = PopoverView(store: store, initialTab: tab, onOpenSettings: {})
                .background(LinearGradient(colors: [Color(red: 0.97, green: 0.71, blue: 0.6),
                                                    Color(red: 0.48, green: 0.61, blue: 1.0),
                                                    Color(red: 0.6, green: 0.42, blue: 1.0)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
            snapshot(view, to: dir.appendingPathComponent("tab-\(tab.rawValue).png"))
        }
        let tabs: [(String, AnyView)] = [
            ("general", AnyView(GeneralSettingsTab(settings: settings))),
            ("menubar", AnyView(MenuBarSettingsTab(settings: settings, store: store))),
            ("alerts", AnyView(AlertSettingsTab(settings: settings))),
        ]
        for (name, content) in tabs {
            snapshot(content.fittedForm().frame(width: 420).background(Color(nsColor: .windowBackgroundColor)),
                     to: dir.appendingPathComponent("settings-\(name).png"))
        }
        let cpu = store.latest.map { store.history.points(.cpuTotal, now: $0.uptime).map(\.value) } ?? []
        let segments = MenuBarContent.segments(items: settings.settings.menuBarItems, snapshot: store.latest,
                                               cpuHistory: cpu, active: store.activeAlerts)
        let icon = MenuBarRenderer.image(segments)
        let image = NSImage(size: NSSize(width: icon.size.width + 16, height: 28), flipped: false) { rect in
            NSColor.windowBackgroundColor.setFill()
            rect.fill()
            icon.draw(at: NSPoint(x: 8, y: (rect.height - icon.size.height) / 2), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("menubar.png"))
        }
    }

    private static func snapshot<V: View>(_ view: V, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
}
