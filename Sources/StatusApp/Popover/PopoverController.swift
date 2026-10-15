import AppKit
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let store: MetricsStore
    private var popover: NSPopover?

    init(store: MetricsStore) {
        self.store = store
        super.init()
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.delegate = self
            popover.contentViewController = NSHostingController(rootView: Text("StatusApp").padding())
            self.popover = popover
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            store.isPopoverOpen = true
        }
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPopoverOpen = false
        popover?.contentViewController = nil
        popover = nil
    }
}
