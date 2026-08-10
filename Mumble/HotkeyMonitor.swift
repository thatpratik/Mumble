//
//  HotkeyMonitor.swift
//  Mumble
//

import AppKit

final class HotkeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var isFnDown = false
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        let fnCurrentlyDown = event.modifierFlags.contains(.function)

        guard fnCurrentlyDown != isFnDown else { return }
        isFnDown = fnCurrentlyDown

        if isFnDown {
            print("Fn DOWN")
            onFnDown?()
        } else {
            print("Fn UP")
            onFnUp?()
        }
    }
}
