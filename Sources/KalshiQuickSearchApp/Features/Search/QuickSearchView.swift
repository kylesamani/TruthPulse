import SwiftUI

struct QuickSearchView: View {
    @ObservedObject private var state: AppState
    @State private var now = Date()
    @State private var spinnerRotation = 0.0

    init(state: AppState) {
        self.state = state
    }

    var body: some View {
        let metrics = state.panelMetrics

        HStack(alignment: .top, spacing: metrics.showDetail ? 12 : 0) {
            VStack(spacing: 12) {
                searchHeader

                if state.results.isEmpty {
                    compactEmptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Color.clear
                                .frame(height: 0)
                                .id("results-top")

                            LazyVStack(spacing: 8) {
                                ForEach(state.results.prefix(8)) { result in
                                    ResultRowView(
                                        result: result,
                                        trend: state.trends["\(result.market.ticker)::\(state.selectedWindow.rawValue)"],
                                        isSelected: state.selectedResultID == result.id,
                                        onTap: {
                                            state.select(result)
                                        }
                                    )
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
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .frame(width: metrics.listWidth)
            .frame(maxHeight: .infinity, alignment: .top)

            if metrics.showDetail {
                DetailPanelView(
                    result: state.selectedResult,
                    trend: state.selectedResult.flatMap { state.trends["\($0.market.ticker)::\(state.selectedWindow.rawValue)"] },
                    selectedWindow: $state.selectedWindow,
                    onWindowChanged: {
                        state.loadSelectedTrend()
                    },
                    onOpenInBrowser: {
                        state.openSelectedMarket()
                    }
                )
                .frame(width: metrics.detailWidth)
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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: metrics)
        .task {
            state.start()
        }
        .onChange(of: state.isRefreshing) { _, isRefreshing in
            spinnerRotation = isRefreshing ? 360 : 0
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
        .onDisappear {
            state.stop()
        }
        .animation(
            state.isRefreshing
                ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                : .default,
            value: spinnerRotation
        )
    }

    private var searchHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                TruthPulseWordmarkView()
                Spacer()
                Button {
                    state.refreshNow()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(Color.truthPulseMint)
                .controlSize(.small)
            }

            SearchFieldView(
                text: Binding(
                    get: { state.query },
                    set: { state.setQuery($0) }
                ),
                onMoveSelection: { state.moveSelection(offset: $0) },
                onSubmit: { state.openSelectedMarket() }
            )
            .frame(height: 40)

            if statusRowVisible {
                HStack {
                    if let statusLabel = statusLabel {
                        HStack(spacing: 6) {
                            Image(systemName: state.isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "clock")
                                .rotationEffect(.degrees(spinnerRotation))

                            Text(statusLabel)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.truthPulseMuted)
                    }

                    Spacer()

                    if let errorMessage = state.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.orange)
                            .lineLimit(1)
                    } else if showNoResultsSummary {
                        Text("No live matches")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.truthPulseMuted)
                    } else if !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("\(state.results.count) results")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.truthPulseMuted)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var compactEmptyState: some View {
        HStack(alignment: .top, spacing: 10) {
            TruthPulseMarkView(size: 28, lineWidth: 2.4)

            VStack(alignment: .leading, spacing: 4) {
                Text(emptyStateTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.truthPulseInk)

                Text(emptyStateSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.truthPulseMuted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
    }

    private var statusLabel: String? {
        if state.isRefreshing {
            return "Syncing all markets..."
        }

        if let lastRefreshDate = state.lastRefreshDate {
            return "Last refreshed all markets \(Formatters.relativeString(for: lastRefreshDate, relativeTo: now))"
        }

        return nil
    }

    private var statusRowVisible: Bool {
        statusLabel != nil || state.errorMessage != nil || !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var trimmedQuery: String {
        state.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showNoResultsSummary: Bool {
        !trimmedQuery.isEmpty && state.results.isEmpty && state.errorMessage == nil && !state.isRefreshing
    }

    private var emptyStateTitle: String {
        if showNoResultsSummary {
            return "No live open markets match \"\(trimmedQuery)\"."
        }
        if state.isRefreshing && trimmedQuery.isEmpty {
            return "Syncing live open Kalshi markets."
        }
        return "Type to search open Kalshi markets."
    }

    private var emptyStateSubtitle: String {
        if showNoResultsSummary {
            return "TruthPulse only searches currently open Kalshi markets, so closed or resolved matches will not appear."
        }
        if state.isRefreshing && trimmedQuery.isEmpty {
            return "Cached results appear first when available, then live Kalshi data refreshes in the background."
        }
        return "Titles, outcomes, event text, and descriptions are indexed locally for fast lookup."
    }
}
