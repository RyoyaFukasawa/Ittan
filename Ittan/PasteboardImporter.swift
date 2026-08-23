import AppKit

@MainActor
enum PasteboardImporter {
    static var acceptedTypes: [NSPasteboard.PasteboardType] {
        let promised = NSFilePromiseReceiver.readableDraggedTypes.map {
            NSPasteboard.PasteboardType($0)
        }
        return [
            .fileURL, .URL, .png, .tiff, .rtfd, .rtf, .html, .string, .color,
            .init("NSFilenamesPboardType"),
            .init("NSFilesPromisePboardType"),
            .init("com.apple.pasteboard.promised-file-url"),
            .init("com.apple.pasteboard.promised-file-content-type"),
            .init("com.apple.filepromise"),
        ] + promised
    }

    static func canImport(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: acceptedTypes) != nil
    }

    @discardableResult
    static func importItems(from pasteboard: NSPasteboard) -> Bool {
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            return ShelfController.shared.add(urls: urls) > 0
        }

        if receivePromisedFiles(from: pasteboard) {
            return true
        }

        if let url = webURL(from: pasteboard) {
            return materializeWebLink(url, title: pasteboard.string(forType: .string))
        }

        if let data = pasteboard.data(forType: .png) {
            return materialize(data, preferredName: "Image", extension: "png")
        }
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            return materialize(png, preferredName: "Image", extension: "png")
        }
        if let data = pasteboard.data(forType: .rtfd) {
            return materialize(data, preferredName: "Text", extension: "rtfd")
        }
        if let data = pasteboard.data(forType: .rtf) {
            return materialize(data, preferredName: "Text", extension: "rtf")
        }
        if let data = pasteboard.data(forType: .html) {
            return materialize(data, preferredName: "Web Content", extension: "html")
        }
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return materialize(Data(string.utf8), preferredName: title(from: string), extension: "txt")
        }
        if let color = NSColor(from: pasteboard) {
            let value = color.usingColorSpace(.sRGB).map {
                String(format: "#%02X%02X%02X%02X", Int($0.redComponent * 255), Int($0.greenComponent * 255), Int($0.blueComponent * 255), Int($0.alphaComponent * 255))
            } ?? color.description
            return materialize(Data(value.utf8), preferredName: "Color \(value)", extension: "txt")
        }
        return false
    }

    private static func webURL(from pasteboard: NSPasteboard) -> URL? {
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self]),
              let url = objects.first as? URL,
              !url.isFileURL else { return nil }
        return url
    }

    private static func materializeWebLink(_ url: URL, title: String?) -> Bool {
        let label = title.flatMap { $0 == url.absoluteString ? nil : $0 } ?? url.host ?? "Link"
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: ["URL": url.absoluteString],
            format: .binary,
            options: 0
        ) else { return false }
        return materialize(data, preferredName: label, extension: "webloc")
    }

    private static func materialize(
        _ data: Data,
        preferredName: String,
        extension fileExtension: String
    ) -> Bool {
        do {
            let directory = try makeItemDirectory()
            let filename = sanitized(preferredName).prefix(80)
            let url = directory.appendingPathComponent(String(filename)).appendingPathExtension(fileExtension)
            try data.write(to: url, options: .atomic)
            return ShelfController.shared.add(urls: [url]) > 0
        } catch {
            NSLog("Ittan: could not store dropped content: \(error.localizedDescription)")
            return false
        }
    }

    private static func receivePromisedFiles(from pasteboard: NSPasteboard) -> Bool {
        guard let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
              !receivers.isEmpty,
              let directory = try? makeItemDirectory() else { return false }

        for receiver in receivers {
            receiver.receivePromisedFiles(atDestination: directory, options: [:], operationQueue: .main) { url, error in
                MainActor.assumeIsolated {
                    if let error {
                        NSLog("Ittan: promised file failed: \(error.localizedDescription)")
                    } else {
                        ShelfController.shared.add(urls: [url])
                    }
                }
            }
        }
        return true
    }

    private static func makeItemDirectory() throws -> URL {
        let root = ShelfStore.defaultItemsURL.deletingLastPathComponent()
            .appendingPathComponent("Items", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func title(from string: String) -> String {
        let firstLine = string.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Text"
        return firstLine.isEmpty ? "Text" : firstLine
    }

    private static func sanitized(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\")
        let result = value.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "Item" : result
    }
}

@MainActor
enum ShelfPasteboardWriter {
    static func make(for item: ShelfItem) -> NSPasteboardWriting {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)

        guard item.path.contains("/Ittan/Items/") else { return pasteboardItem }
        switch item.url.pathExtension.lowercased() {
        case "webloc":
            if let data = try? Data(contentsOf: item.url),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dictionary = plist as? [String: String],
               let url = dictionary["URL"] {
                pasteboardItem.setString(url, forType: .URL)
                pasteboardItem.setString(url, forType: .string)
            }
        case "txt":
            if let string = try? String(contentsOf: item.url, encoding: .utf8) {
                pasteboardItem.setString(string, forType: .string)
            }
        case "html":
            if let data = try? Data(contentsOf: item.url) {
                pasteboardItem.setData(data, forType: .html)
            }
        case "rtf":
            if let data = try? Data(contentsOf: item.url) {
                pasteboardItem.setData(data, forType: .rtf)
            }
        case "png":
            if let data = try? Data(contentsOf: item.url) {
                pasteboardItem.setData(data, forType: .png)
            }
        default:
            break
        }
        return pasteboardItem
    }
}
