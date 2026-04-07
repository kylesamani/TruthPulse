#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import TruthPulseCore

struct IOSSearchView: View {
    @ObservedObject var state: IOSAppState
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !state.hasCachedMarkets && state.isRefreshing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Syncing markets...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if state.results.isEmpty && !trimmedQuery.isEmpty && trimmedQuery.count >= 4 {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else if state.results.isEmpty {
                    VStack(spacing: 12) {
                        TruthPulseMarkView(size: 56, lineWidth: 5)
                        Text("Search Kalshi markets")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .navigationTitle("TruthPulse")
            .searchable(
                text: Binding(
                    get: { state.query },
                    set: { state.setQuery($0) }
                ),
                prompt: "Search all Kalshi markets"
            )
            .refreshable {
                await state.refreshMarkets()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                IOSSettingsView(state: state)
            }
        }
        .onAppear { state.onAppear() }
    }

    private var resultsList: some View {
        List(state.results) { result in
            Button {
                openMarket(result.market)
            } label: {
                IOSResultRowView(
                    result: result,
                    trend: state.trend(for: result.market)
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .onAppear {
                state.loadTrendIfNeeded(for: result.market)
            }
            .accessibilityLabel("\(result.market.title), \(result.emphasizedOdds.map { "\($0) percent" } ?? "no odds") \(result.emphasizedOutcomeLabel)")
            .accessibilityHint("Opens market on Kalshi")
        }
        .listStyle(.plain)
    }

    private var trimmedQuery: String {
        state.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func openMarket(_ market: MarketSummary) {
        let url = market.resolvedWebURL
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}
