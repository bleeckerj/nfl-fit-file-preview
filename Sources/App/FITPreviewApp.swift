import SwiftUI
import AppKit

@main
struct FITPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("FIT Preview", id: "setup") {
            SetupView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        // Opening a document retains a setup-only host; Finder provides the preview.
        sender.reply(toOpenOrPrint: .success)
    }
}
