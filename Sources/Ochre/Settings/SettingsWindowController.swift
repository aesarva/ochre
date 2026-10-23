import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: SettingsStore
    private let store: MetricsStore
    private let updates: UpdateController
    private var window: NSWindow?

    init(settings: SettingsStore, store: MetricsStore, updates: UpdateController) {
        self.settings = settings
        self.store = store
        self.updates = updates
        super.init()
    }

    func show() {
        if window == nil {
            // Стандартное окно настроек macOS: вкладки со значками в панели инструментов, окно подстраивает
            // высоту под вкладку. Заголовок окна — имя выбранной вкладки.
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for tab in SettingsTab.allCases {
                let host = NSHostingController(rootView: tab.content(settings: settings, store: store, updates: updates)
                    .fittedForm()
                    .frame(width: 420))
                host.sizingOptions = [.preferredContentSize]
                host.title = tab.title
                let item = NSTabViewItem(viewController: host)
                item.label = tab.title
                item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
                tabs.addTabViewItem(item)
            }
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Debug aid for `-SnapshotDir`: the whole window, toolbar included, for every tab.
    func exportSnapshots(to dir: URL) async {
        show()
        guard let window, let tabs = window.contentViewController as? NSTabViewController else { return }
        for (index, tab) in SettingsTab.allCases.enumerated() {
            tabs.selectedTabViewItemIndex = index
            try? await Task.sleep(for: .milliseconds(700)) // окно анимирует высоту под вкладку
            guard let frame = window.contentView?.superview,
                  let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { continue }
            frame.cacheDisplay(in: frame.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: dir.appendingPathComponent("window-settings-\(index)-\(tab.symbol).png"))
        }
        window.close()
    }

    /// Drops the window and its hosting controller so the SwiftUI view tree is freed; recreated on next show().
    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window?.contentViewController = nil
        window = nil
    }
}
