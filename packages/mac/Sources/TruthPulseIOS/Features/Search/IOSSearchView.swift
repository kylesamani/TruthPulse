#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import TruthPulseCore

struct IOSSearchView: View {
    @ObservedObject var state: IOSAppState
    @State private var showSettings = false
    @State private var didAppear = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TruthPulse")
                    .font(.largeTitle.weight(.bold))
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all Kalshi markets", text: Binding(
                    get: { state.query },
                    set: { state.setQuery($0) }
                ))
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                if !state.query.isEmpty {
                    Button {
                        state.setQuery("")
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Content
            if !state.hasCachedMarkets && state.isRefreshing {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Text("Syncing markets...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                Spacer()
            } else if state.results.isEmpty && !trimmedQuery.isEmpty && trimmedQuery.count >= 4 {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No markets found")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else if state.results.isEmpty {
                Spacer()
                TruthPulseMarkView(size: 56, lineWidth: 5)
                Text("Search Kalshi markets")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                List {
                    ForEach(state.results) { result in
                        Button {
                            openMarket(result.market)
                        } label: {
                            IOSResultRowView(
                                result: result,
                                trend: state.trend(for: result.market)
                            )
                        }
                        .onAppear {
                            state.loadTrendIfNeeded(for: result.market)
                        }
                        .accessibilityLabel("\(result.market.title), \(result.emphasizedOdds.map { "\($0) percent" } ?? "no odds") \(result.emphasizedOutcomeLabel)")
                        .accessibilityHint("Opens market on Kalshi")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showSettings) {
            IOSSettingsView(state: state)
        }
        .task {
            guard !didAppear else { return }
            didAppear = true
            state.onAppear()
        }
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
