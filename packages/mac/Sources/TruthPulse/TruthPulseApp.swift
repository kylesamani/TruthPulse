import SwiftUI

@main
struct TruthPulseApp: App {
    @NSApplicationDelegateAdaptor(TruthPulseAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 10) {
                TruthPulseWordmarkView()
                Text("TruthPulse")
                    .font(.system(size: 22, weight: .bold))
                Text("Native menu bar lookup for live Kalshi markets. Use the menu bar icon to open the fast search panel.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}
