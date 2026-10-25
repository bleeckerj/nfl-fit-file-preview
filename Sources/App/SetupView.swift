import SwiftUI
import AppKit

struct SetupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 34))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FIT Preview").font(.title.bold())
                    Text("Recorded routes in Finder Quick Look")
                        .foregroundStyle(.secondary)
                }
            }
            Text("Select a .fit or .gpx file in Finder and press the space bar. The preview shows the route on a map, with distance and time when available. GPX distance is approximate; GPX time is elapsed time within each segment.")
                .fixedSize(horizontal: false, vertical: true)
            Text("If Finder shows only a file icon, enable FIT Route Preview under System Settings → General → Login Items & Extensions → Quick Look. Keep this app in your Applications folder.")
                .fixedSize(horizontal: false, vertical: true)
            Text("FIT and GPX files are decoded on your Mac. Apple Maps uses a network connection for geographic imagery. GPS gaps remain separate on the map.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Extension Settings") {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") else { return }
                    NSWorkspace.shared.open(url)
                }
                Spacer()
                Button("Done") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
