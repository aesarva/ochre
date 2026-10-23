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
            let host = NSHostingController(rootView: SettingsView(settings: settings, store: store, updates: updates))
            host.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: host)
            window.title = "Настройки Ochre"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Drops the window and its hosting controller so the SwiftUI view tree is freed; recreated on next show().
    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window?.contentViewController = nil
        window = nil
    }
}
