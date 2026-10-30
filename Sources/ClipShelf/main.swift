import AppKit
import Darwin

if CommandLine.arguments.contains("--self-test-screenshot") {
    MainActor.assumeIsolated {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipShelf-screenshot-test-\(UUID().uuidString)", isDirectory: true)
        let screenshotDirectory = root.appendingPathComponent("screenshots", isDirectory: true)
        let storage = root.appendingPathComponent("storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)

        let testPasteboard = NSPasteboard(name: .init("local.clipshelf.screenshot-test"))
        let store = ClipboardStore(
            pasteboard: testPasteboard,
            storageDirectory: storage,
            automaticallyMonitor: false
        )
        let monitor = ScreenshotMonitor(
            store: store,
            directoryProvider: { screenshotDirectory },
            automaticallyMonitor: true
        )

        let image = NSImage(size: NSSize(width: 32, height: 24))
        image.lockFocus()
        NSColor.systemIndigo.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 32, height: 24)).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Screenshot monitor self-test could not create fixture\n", stderr)
            exit(1)
        }

        let screenshotURL = screenshotDirectory.appendingPathComponent("fixture.png")
        try? pngData.write(to: screenshotURL, options: .atomic)
        var marker: UInt8 = 1
        let xattrStatus = screenshotURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return withUnsafePointer(to: &marker) { pointer in
                setxattr(
                    path,
                    "com.apple.metadata:kMDItemIsScreenCapture",
                    pointer,
                    1,
                    0,
                    0
                )
            }
        }
        guard xattrStatus == 0 else {
            fputs("Screenshot monitor self-test could not set metadata\n", stderr)
            exit(1)
        }

        withExtendedLifetime(monitor) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        guard store.items.first?.kind == .image,
              (store.items.first?.pixelWidth ?? 0) > 0,
              (store.items.first?.pixelHeight ?? 0) > 0,
              store.image(for: store.items[0]) != nil,
              store.items.count == 1 else {
            fputs("Screenshot monitor self-test failed\n", stderr)
            exit(1)
        }

        guard testPasteboard.data(forType: .png) != nil else {
            fputs("Screenshot clipboard self-test failed\n", stderr)
            exit(1)
        }

        try? FileManager.default.removeItem(at: root)
        print("Screenshot monitor self-test passed")
    }
} else if CommandLine.arguments.contains("--self-test-text") {
    MainActor.assumeIsolated {
        let pasteboard = NSPasteboard(name: .init("local.clipshelf.self-test"))
        let storage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipShelf-self-test-\(UUID().uuidString)", isDirectory: true)
        let store = ClipboardStore(
            pasteboard: pasteboard,
            storageDirectory: storage,
            automaticallyMonitor: false
        )

        pasteboard.clearContents()
        pasteboard.setString("ClipShelf text self-test", forType: .string)
        store.checkPasteboardNow()

        guard store.items.first?.kind == .text,
              store.items.first?.text == "ClipShelf text self-test" else {
            fputs("Text clipboard self-test failed\n", stderr)
            exit(1)
        }

        try? FileManager.default.removeItem(at: storage)
        print("Text clipboard self-test passed")
    }
} else {
    MainActor.assumeIsolated {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
