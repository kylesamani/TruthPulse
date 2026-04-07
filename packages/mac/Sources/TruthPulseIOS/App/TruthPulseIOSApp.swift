import SwiftUI
import CoreSpotlight
import TruthPulseCore

@main
struct TruthPulseIOSApp: App {
    @StateObject private var state = IOSAppState()

    var body: some Scene {
        WindowGroup {
            IOSSearchView(state: state)
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    state.handleSpotlightContinuation(activity)
                }
        }
    }
}
