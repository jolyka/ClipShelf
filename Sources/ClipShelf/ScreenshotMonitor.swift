import AppKit
import Darwin
import Foundation

@MainActor
final class ScreenshotMonitor {
    private let store: ClipboardStore
    private let fileManager = FileManager.default
    private let directoryProvider: @MainActor () -> URL
    private var observedDirectory: URL?
    private var seenPaths = Set<String>()
    private var timer: Timer?
    private var directorySource: DispatchSourceFileSystemObject?

    init(
        store: ClipboardStore,
        directoryProvider: @escaping @MainActor () -> URL = ScreenshotMonitor.defaultScreenshotDirectory,
        automaticallyMonitor: Bool = true
    ) {
        self.store = store
        self.directoryProvider = directoryProvider
        resetDirectoryBaseline()

        if automaticallyMonitor {
            installDirectoryWatcher()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scanNow() }
            }
            timer?.tolerance = 0.15
        }
    }

    deinit {
        timer?.invalidate()
        directorySource?.cancel()
    }

    func scanNow() {
        let directory = directoryProvider().standardizedFileURL
        guard directory == observedDirectory else {
            resetDirectoryBaseline()
            installDirectoryWatcher()
            return
        }

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let newScreenshots = urls
                .filter { isSupportedImage($0) && !seenPaths.contains($0.path) && hasScreenCaptureMetadata($0) }
                .sorted { screenshotDate($0) < screenshotDate($1) }

            for url in newScreenshots {
                if store.importScreenshotFile(at: url) {
                    seenPaths.insert(url.path)
                }
            }
        } catch {
            store.reportScreenshotFolderUnavailable()
        }
    }

    private func resetDirectoryBaseline() {
        let directory = directoryProvider().standardizedFileURL
        observedDirectory = directory
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        seenPaths = Set(urls.map(\.path))
    }

    private func installDirectoryWatcher() {
        directorySource?.cancel()
        directorySource = nil

        let directory = directoryProvider().standardizedFileURL
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            store.reportScreenshotFolderUnavailable()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.scanImmediatelyWithRetries()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        directorySource = source
    }

    private func scanImmediatelyWithRetries() {
        scanNow()

        for delay in [0.015, 0.05, 0.12] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task { @MainActor [weak self] in self?.scanNow() }
            }
        }
    }

    private func isSupportedImage(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "heic", "tiff"].contains(url.pathExtension.lowercased())
    }

    private func screenshotDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate ?? .distantPast
    }

    private func hasScreenCaptureMetadata(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(
                path,
                "com.apple.metadata:kMDItemIsScreenCapture",
                nil,
                0,
                0,
                0
            ) > 0
        }
    }

    private static func defaultScreenshotDirectory() -> URL {
        if let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture"),
           let configuredPath = domain["location"] as? String,
           !configuredPath.isEmpty {
            return URL(fileURLWithPath: NSString(string: configuredPath).expandingTildeInPath, isDirectory: true)
        }

        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
}
