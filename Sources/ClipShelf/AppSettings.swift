import Carbon
import Foundation

struct ShortcutPreset: Identifiable, Hashable {
    let id: String
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32
}

@MainActor
final class AppSettings: ObservableObject {
    static let showPresets: [ShortcutPreset] = [
        .init(id: "show-c", title: "⌃⌥⌘C", keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        .init(id: "show-v", title: "⌃⌥⌘V", keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        .init(id: "show-space", title: "⌃⌥Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))
    ]

    static let clearPresets: [ShortcutPreset] = [
        .init(id: "clear-delete", title: "⌃⌥⌘⌫", keyCode: UInt32(kVK_Delete), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        .init(id: "clear-x", title: "⌃⌥⌘X", keyCode: UInt32(kVK_ANSI_X), modifiers: UInt32(controlKey | optionKey | cmdKey)),
        .init(id: "clear-forward", title: "⌃⌥⌘⌦", keyCode: UInt32(kVK_ForwardDelete), modifiers: UInt32(controlKey | optionKey | cmdKey))
    ]

    @Published var showShortcutID: String {
        didSet {
            UserDefaults.standard.set(showShortcutID, forKey: Keys.showShortcut)
            NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
        }
    }

    @Published var clearShortcutID: String {
        didSet {
            UserDefaults.standard.set(clearShortcutID, forKey: Keys.clearShortcut)
            NotificationCenter.default.post(name: .shortcutsDidChange, object: nil)
        }
    }

    var showShortcut: ShortcutPreset {
        Self.showPresets.first(where: { $0.id == showShortcutID }) ?? Self.showPresets[0]
    }

    var clearShortcut: ShortcutPreset {
        Self.clearPresets.first(where: { $0.id == clearShortcutID }) ?? Self.clearPresets[0]
    }

    init() {
        showShortcutID = UserDefaults.standard.string(forKey: Keys.showShortcut) ?? Self.showPresets[0].id
        clearShortcutID = UserDefaults.standard.string(forKey: Keys.clearShortcut) ?? Self.clearPresets[0].id
    }

    private enum Keys {
        static let showShortcut = "showShortcut"
        static let clearShortcut = "clearShortcut"
    }
}

extension Notification.Name {
    static let shortcutsDidChange = Notification.Name("ClipShelf.shortcutsDidChange")
    static let showShelf = Notification.Name("ClipShelf.showShelf")
    static let clearShelf = Notification.Name("ClipShelf.clearShelf")
}
