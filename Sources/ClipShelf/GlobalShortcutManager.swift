import Carbon
import Foundation

private let shortcutEventHandler: EventHandlerUPP = { _, event, _ in
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    switch hotKeyID.id {
    case 1:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .showShelf, object: nil)
        }
    case 2:
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clearShelf, object: nil)
        }
    default:
        break
    }
    return noErr
}

@MainActor
final class GlobalShortcutManager {
    private var showHotKey: EventHotKeyRef?
    private var clearHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            shortcutEventHandler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        registerShortcuts()
        NotificationCenter.default.addObserver(
            forName: .shortcutsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.registerShortcuts() }
        }
    }

    deinit {
        if let showHotKey { UnregisterEventHotKey(showHotKey) }
        if let clearHotKey { UnregisterEventHotKey(clearHotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private func registerShortcuts() {
        if let showHotKey { UnregisterEventHotKey(showHotKey) }
        if let clearHotKey { UnregisterEventHotKey(clearHotKey) }
        showHotKey = nil
        clearHotKey = nil

        let signature = fourCharacterCode("CLSH")
        let show = settings.showShortcut
        let clear = settings.clearShortcut

        RegisterEventHotKey(
            show.keyCode,
            show.modifiers,
            EventHotKeyID(signature: signature, id: 1),
            GetEventDispatcherTarget(),
            0,
            &showHotKey
        )
        RegisterEventHotKey(
            clear.keyCode,
            clear.modifiers,
            EventHotKeyID(signature: signature, id: 2),
            GetEventDispatcherTarget(),
            0,
            &clearHotKey
        )
    }

    private func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
