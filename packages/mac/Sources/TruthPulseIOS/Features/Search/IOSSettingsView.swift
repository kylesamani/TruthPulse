#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import TruthPulseCore

struct IOSSettingsView: View {
    @ObservedObject var state: IOSAppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Sync") {
                    Picker("Refresh interval", selection: $state.syncInterval) {
                        ForEach(IOSSyncInterval.allCases, id: \.self) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }

                    if let lastSync = state.lastSyncDate {
                        HStack {
                            Text("Last synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                            Text("ago")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Trend") {
                    Picker("Default window", selection: $state.selectedWindow) {
                        ForEach(TrendWindow.allCases) { window in
                            Text(window.title).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        openFeedbackEmail()
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundStyle(Color.truthPulseMint)
                            Text("Send feedback / report bugs")
                        }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Opens your email app to send feedback to the TruthPulse team.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Data source")
                        Spacer()
                        Text("Kalshi")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func openFeedbackEmail() {
        #if canImport(UIKit)
        let subject = "TruthPulse iOS Feedback"
        let urlString = "mailto:truthpulse@kylesamani.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
