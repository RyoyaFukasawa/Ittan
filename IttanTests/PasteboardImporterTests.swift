import AppKit
import Testing
@testable import Ittan

@MainActor
@Suite("Pasteboard importer")
struct PasteboardImporterTests {
    @Test("Recognizes browser URLs and text")
    func recognizesBrowserContent() {
        let urlPasteboard = NSPasteboard.withUniqueName()
        urlPasteboard.declareTypes([.URL], owner: nil)
        urlPasteboard.setString("https://example.com", forType: .URL)
        #expect(PasteboardImporter.canImport(urlPasteboard))

        let textPasteboard = NSPasteboard.withUniqueName()
        textPasteboard.declareTypes([.string], owner: nil)
        textPasteboard.setString("temporary text", forType: .string)
        #expect(PasteboardImporter.canImport(textPasteboard))
    }

    @Test("Rejects unsupported private data")
    func rejectsUnsupportedData() {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.declareTypes([.init("dev.ittan.unsupported")], owner: nil)
        #expect(!PasteboardImporter.canImport(pasteboard))
    }
}
