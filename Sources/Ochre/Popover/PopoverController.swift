import AppKit
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let store: MetricsStore
    private let initialTab: PopoverTab
    private let onOpenSettings: () -> Void
    private var popover: NSPopover?
    private var clickMonitor: Any?
    private var resignObserver: (any NSObjectProtocol)?

    init(store: MetricsStore, initialTab: PopoverTab = .overview, onOpenSettings: @escaping () -> Void = {}) {
        self.store = store
        self.initialTab = initialTab
        self.onOpenSettings = onOpenSettings
        super.init()
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { if self?.popover?.isShown == true { self?.close() } }
        }
    }

    isolated deinit {
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        removeClickMonitor()
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            // Прошлая панель может ещё доигрывать закрытие: её монитор и ссылку убираем сразу,
            // иначе её запоздалый popoverDidClose погасит уже новую панель.
            removeClickMonitor()
            let popover = NSPopover()
            popover.behavior = .transient
            popover.delegate = self
            var view = PopoverView(store: store, initialTab: initialTab, onOpenSettings: onOpenSettings)
            // Размер панели задаём сами через contentSize: так NSPopover меняет его, держась за стрелку у значка.
            // Автоматический режим (preferredContentSize) сначала растит окно от нижнего края, а потом
            // сдвигает его обратно — панель с вкладками прыгает; без размера окно ставится под 320×320.
            view.onSizeChange = { [weak popover] size in
                guard let popover, size.height > 0, popover.contentSize != size else { return }
                popover.contentSize = size
            }
            let host = NSHostingController(rootView: view)
            host.sizingOptions = []
            popover.contentViewController = host
            popover.contentSize = host.view.fittingSize
            self.popover = popover
            NSApp.activate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Стеклянный фон панели темнеет, пока её окно не ключевое. Запрос активации выше macOS 26
            // для приложения из строки меню обычно отклоняет, и панель оставалась тёмной до первого клика.
            // Окно панели — неактивирующая NSPanel: makeKey() делает её ключевой (и приложение активным) сразу.
            popover.contentViewController?.view.window?.makeKey()
            store.isPopoverOpen = true
            // Safety net: clicks in other apps close the popover even if activation was refused
            // (a transient popover in an inactive LSUIElement app otherwise stays open).
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            }
        }
    }

    func close() {
        popover?.performClose(nil)
    }

    var isShown: Bool { popover?.isShown == true }

    func popoverDidClose(_ notification: Notification) {
        let closed = notification.object as? NSPopover
        closed?.contentViewController = nil
        guard closed === popover else { return }
        store.isPopoverOpen = false
        removeClickMonitor()
        popover = nil
    }

    private func removeClickMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }
}
