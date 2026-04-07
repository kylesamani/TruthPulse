import SwiftUI
import TruthPulseCore

struct QuickSearchView: View {
    @ObservedObject private var state: AppState
    @State private var now = Date()

    init(state: AppState) {
        self.state = state
    }

    var body: some View {
        let metrics = state.panelMetrics

        VStack(spacing: 8) {
            searchHeader

            if !state.results.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear
                            .frame(height: 0)
                            .id("results-top")

                        LazyVStack(spacing: 8) {
                            ForEach(state.results) { result in
                                ResultRowView(
                                    result: result,
                                    trend: state.trends["\(result.market.ticker)::\(state.selectedWindow.rawValue)"],
                                    isSelected: state.selectedResultID == result.id,
                                    onTap: {
                                        state.select(result)
                                    }
                                )
                                .id(result.id)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 8)
                    }
                    .defaultScrollAnchor(.top)
                    .onAppear {
                        proxy.scrollTo("results-top", anchor: .top)
                    }
                    .onChange(of: state.results.map(\.id)) { _, _ in
                        proxy.scrollTo("results-top", anchor: .top)
                    }
                    .onChange(of: state.selectedResultID) { _, newID in
                        if let newID {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(14)
        .frame(width: metrics.width, height: metrics.height, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color.kalshiMintSoft,
                    Color.white,
                    Color(red: 0.95, green: 0.99, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: metrics)
        .task {
            state.onPopoverOpen()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
    }

    private var searchHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                TruthPulseWordmarkView()

                Text(".co")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.truthPulseMuted)
                    .padding(.leading, -6)

                Text("powered by Kalshi")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.truthPulseMuted)
                    .padding(.leading, 6)

                Spacer()

                Picker("", selection: $state.selectedWindow) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .onChange(of: state.selectedWindow) { _, _ in
                    state.loadSelectedTrend()
                }
            }

            SearchFieldView(
                text: Binding(
                    get: { state.query },
                    set: { state.setQuery($0) }
                ),
                isEnabled: state.hasCachedMarkets,
                placeholderText: searchPlaceholder,
                onMoveSelection: { state.moveSelection(offset: $0) },
                onSubmit: { state.openSelectedMarket() }
            )
            .frame(height: 40)

            syncStatusRow
        }
    }

    private var searchPlaceholder: String {
        if !state.hasCachedMarkets {
            return "First time setup and sync. Please wait a moment."
        }
        if state.lastSyncDate != nil {
            return "Search all Kalshi markets."
        }
        return "Search locally cached markets."
    }

    private var syncStatusRow: some View {
        HStack {
            Group {
                if state.isRefreshing {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Syncing with kalshi.com...")
                    }
                } else if let syncDate = state.lastSyncDate {
                    Text("Last synced with kalshi.com \(humanInterval(from: syncDate, to: now)) ago.")
                } else {
                    Text(" ")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.truthPulseMuted)

            Spacer()

            if let errorMessage = state.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            } else if showNoResultsSummary {
                Text("No matches")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.truthPulseMuted)
            } else if !trimmedQuery.isEmpty {
                Text("\(state.results.count) results")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.truthPulseMuted)
            }
        }
        .padding(.horizontal, 4)
    }

    private var trimmedQuery: String {
        state.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showNoResultsSummary: Bool {
        !trimmedQuery.isEmpty && state.results.isEmpty && state.errorMessage == nil && !state.isRefreshing
    }

    private func humanInterval(from start: Date, to end: Date) -> String {
        let seconds = Int(max(0, end.timeIntervalSince(start)))
        if seconds < 60 {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}
