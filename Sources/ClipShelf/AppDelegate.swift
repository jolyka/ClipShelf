import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = ClipboardStore()
    private let settings = AppSettings()
    private var shortcutManager: GlobalShortcutManager?
    private var screenshotMonitor: ScreenshotMonitor?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        disableFloatingScreenshotThumbnail()
        shortcutManager = GlobalShortcutManager(settings: settings)
        screenshotMonitor = ScreenshotMonitor(store: store)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.stack.badge.plus", accessibilityDescription: "ClipShelf")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 440, height: 610)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(store: store, settings: settings)
        )

        observers.append(NotificationCenter.default.addObserver(forName: .showShelf, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.showPopover() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .clearShelf, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.store.clearAll() }
        })

        DispatchQueue.main.async { [weak self] in
            self?.showPopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showPopover()
        return true
    }

    @objc private func togglePopover() {
        guard let event = NSApp.currentEvent else {
            showPopover()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Открыть ClipShelf", action: #selector(openFromMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Очистить историю", action: #selector(clearFromMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Завершить ClipShelf", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items { item.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openFromMenu() {
        showPopover()
    }

    @objc private func clearFromMenu() {
        store.clearAll()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func disableFloatingScreenshotThumbnail() {
        var preferences = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture") ?? [:]
        preferences["show-thumbnail"] = false
        UserDefaults.standard.setPersistentDomain(preferences, forName: "com.apple.screencapture")
    }
}
