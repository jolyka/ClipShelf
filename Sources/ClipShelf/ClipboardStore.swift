import AppKit
import CryptoKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var lastAction = "Готово"

    private let pasteboard: NSPasteboard
    private let fileManager = FileManager.default
    private let maximumItemCount = 30
    private var monitorTimer: Timer?
    private var observedChangeCount: Int
    private let storageDirectory: URL

    private var indexURL: URL {
        storageDirectory.appendingPathComponent("items.json")
    }

    init(
        pasteboard: NSPasteboard = .general,
        storageDirectory: URL? = nil,
        automaticallyMonitor: Bool = true
    ) {
        self.pasteboard = pasteboard
        self.storageDirectory = storageDirectory ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipShelf", isDirectory: true)
        observedChangeCount = pasteboard.changeCount
        loadIndex()
        if automaticallyMonitor {
            startMonitoring()
        }
    }

    deinit {
        monitorTimer?.invalidate()
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard let filename = item.filename else { return nil }
        return NSImage(contentsOf: storageDirectory.appendingPathComponent(filename))
    }

    func copy(_ item: ClipboardItem) {
        switch item.kind {
        case .image:
            guard let filename = item.filename,
                  let data = try? Data(contentsOf: storageDirectory.appendingPathComponent(filename)) else {
                lastAction = "Не удалось открыть изображение"
                return
            }
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .png)
            lastAction = "Изображение скопировано"
        case .text:
            guard let text = item.text else {
                lastAction = "Не удалось открыть текст"
                return
            }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            lastAction = "Текст скопирован"
        }
        observedChangeCount = pasteboard.changeCount
    }

    func delete(_ item: ClipboardItem) {
        if let filename = item.filename {
            try? fileManager.removeItem(at: storageDirectory.appendingPathComponent(filename))
        }
        items.removeAll { $0.id == item.id }
        saveIndex()
        lastAction = "Запись удалена"
    }

    func clearAll() {
        for item in items {
            if let filename = item.filename {
                try? fileManager.removeItem(at: storageDirectory.appendingPathComponent(filename))
            }
        }
        items.removeAll()
        saveIndex()
        lastAction = "История очищена"
    }

    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.capturePasteboardContentIfNeeded()
            }
        }
    }

    func checkPasteboardNow() {
        capturePasteboardContentIfNeeded()
    }

    @discardableResult
    func importScreenshotFile(at url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return false }

        guard captureImage(pngData) else { return false }
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
        observedChangeCount = pasteboard.changeCount
        lastAction = "Снимок сохранён и скопирован"
        return true
    }

    func reportScreenshotFolderUnavailable() {
        lastAction = "Нужен доступ к папке скриншотов"
    }

    private func capturePasteboardContentIfNeeded() {
        let changeCount = pasteboard.changeCount
        guard changeCount != observedChangeCount else { return }
        observedChangeCount = changeCount

        guard !containsProtectedContent(pasteboard) else {
            lastAction = "Скрытые данные пропущены"
            return
        }

        if let pngData = normalizedPNGData(from: pasteboard) {
            captureImage(pngData)
        } else if let text = pasteboard.string(forType: .string) {
            captureText(text)
        }
    }

    @discardableResult
    private func captureImage(_ pngData: Data) -> Bool {
        guard let image = NSImage(data: pngData),
              let representation = image.representations.first else { return false }

        let digest = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        guard !items.contains(where: { $0.digest == digest }) else { return true }

        do {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            let id = UUID()
            let filename = "\(id.uuidString).png"
            try pngData.write(to: storageDirectory.appendingPathComponent(filename), options: .atomic)

            let item = ClipboardItem(
                id: id,
                kind: .image,
                filename: filename,
                createdAt: Date(),
                pixelWidth: representation.pixelsWide,
                pixelHeight: representation.pixelsHigh,
                byteCount: pngData.count,
                digest: digest
            )
            items.insert(item, at: 0)
            trimOldItems()
            saveIndex()
            lastAction = "Новый снимок сохранён"
            return true
        } catch {
            lastAction = "Не удалось сохранить снимок"
            return false
        }
    }

    private func captureText(_ rawText: String) {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = rawText.data(using: .utf8) else { return }

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard !items.contains(where: { $0.digest == digest }) else { return }

        let item = ClipboardItem(
            id: UUID(),
            kind: .text,
            text: rawText,
            createdAt: Date(),
            byteCount: data.count,
            digest: digest
        )
        items.insert(item, at: 0)
        trimOldItems()
        saveIndex()
        lastAction = "Новый текст сохранён"
    }

    private func containsProtectedContent(_ pasteboard: NSPasteboard) -> Bool {
        let protectedTypes = [
            "org.nspasteboard.TransientType",
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.AutoGeneratedType"
        ].map { NSPasteboard.PasteboardType(rawValue: $0) }

        return protectedTypes.contains { pasteboard.types?.contains($0) == true }
    }

    private func normalizedPNGData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) {
            return png
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func trimOldItems() {
        guard items.count > maximumItemCount else { return }
        let overflow = items.suffix(from: maximumItemCount)
        for item in overflow {
            if let filename = item.filename {
                try? fileManager.removeItem(at: storageDirectory.appendingPathComponent(filename))
            }
        }
        items = Array(items.prefix(maximumItemCount))
    }

    private func loadIndex() {
        do {
            let data = try Data(contentsOf: indexURL)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            items = decoded.filter {
                guard $0.kind == .image else { return $0.text != nil }
                guard let filename = $0.filename else { return false }
                return fileManager.fileExists(atPath: storageDirectory.appendingPathComponent(filename).path)
            }
        } catch {
            items = []
        }
    }

    private func saveIndex() {
        do {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(items).write(to: indexURL, options: .atomic)
        } catch {
            lastAction = "Не удалось обновить историю"
        }
    }
}
