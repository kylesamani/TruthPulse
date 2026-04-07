import SwiftUI
import TruthPulseCore

// @main — uncomment when building via Xcode for iOS target
struct TruthPulseIOSApp: App {
    @StateObject private var state = IOSAppState()

    var body: some Scene {
        WindowGroup {
            IOSSearchView(state: state)
        }
    }
}
