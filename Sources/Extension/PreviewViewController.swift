import AppKit
import QuickLookUI

@MainActor
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var decodeTask: Task<RouteSummary, Error>?
    private var generation = 0
    private var preview: RoutePreviewView { view as! RoutePreviewView }

    override func loadView() {
        view = RoutePreviewView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
        preferredContentSize = NSSize(width: 900, height: 620)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        decodeTask?.cancel()
        generation += 1
        let requestGeneration = generation
        preview.loading(filename: url.lastPathComponent)
        let task = Task.detached(priority: .userInitiated) { try FITRouteDecoder.decode(url: url) }
        decodeTask = task
        Task { [weak self] in
            do {
                let summary = try await task.value
                guard let self, requestGeneration == self.generation else {
                    handler(CancellationError())
                    return
                }
                self.preview.display(summary)
                self.decodeTask = nil
                handler(nil)
            } catch {
                guard let self, requestGeneration == self.generation else {
                    handler(CancellationError())
                    return
                }
                self.decodeTask = nil
                if error is CancellationError {
                    handler(error)
                } else {
                    // A successful completion lets Quick Look display our readable error state.
                    self.preview.showError(error)
                    handler(nil)
                }
            }
        }
    }

    deinit { decodeTask?.cancel() }
}
