# TruthPulse — Kalshi Quick Search

## What This Is
Native macOS menu bar app for instant Kalshi prediction market lookup. Keyboard-driven search, live odds, trend sparklines, zero backend.

## Commands
- `swift build` — Build the project
- `swift run KalshiQuickSearchApp` — Run the app
- `swift test` — Run tests
- `swift package clean` — Clean build artifacts

## Architecture

### Stack
- **Language**: Swift 6.0
- **Platform**: macOS 14+ (Sonoma)
- **UI**: SwiftUI + AppKit (menu bar integration)
- **Package Manager**: Swift Package Manager (zero external dependencies)
- **API**: Kalshi public REST (`https://api.elections.kalshi.com/trade-api/v2`)
- **Concurrency**: Swift actors, async/await

### Structure
```
Sources/KalshiQuickSearchApp/
├── App/
│   ├── AppState.swift              # Central @Published state management
│   └── TruthPulseAppDelegate.swift # Menu bar setup, popover, app lifecycle
├── Features/Search/
│   ├── QuickSearchView.swift       # Main UI container (search + results + detail)
│   ├── SearchFieldView.swift       # Input field with keyboard handling
│   ├── ResultRowView.swift         # Individual market result card
│   ├── DetailPanelView.swift       # Right-side detail panel with large sparkline
│   ├── SparklineView.swift         # Trend sparkline chart
│   └── CachedAsyncImage.swift      # Image loading with disk cache
├── Models/
│   ├── MarketModels.swift          # MarketSummary, SearchResult, HighlightRange
│   ├── TrendModels.swift           # TrendWindow, MarketTrend, TrendPoint
│   └── JSONValue.swift             # Generic JSON type handling
├── Services/
│   ├── KalshiAPIClient.swift       # REST API client (markets + candlesticks)
│   ├── SearchService.swift         # Core search logic, caching, trend fetch (actor)
│   ├── RankingPolicy.swift         # Multi-signal ranking (text relevance + liquidity)
│   ├── MarketCacheStore.swift      # JSON disk persistence for markets
│   └── ImageRepository.swift       # Image download & disk caching
└── Support/
    ├── TruthPulseBrand.swift       # Brand colors, glyph/wordmark shapes
    └── Formatting.swift            # Number/date formatters
```

### Key Design Decisions
- **No backend**: All data fetched directly from Kalshi public API
- **Local search index**: Markets cached locally for instant typeahead
- **Lazy trend loading**: Candlestick data fetched on selection, not upfront
- **Actor-based SearchService**: Thread-safe concurrent access
- **Field-aware ranking**: Title matches ranked higher than description matches, boosted by volume/liquidity

### Data Flow
1. App boots → loads cached markets from disk (instant search available)
2. Background poll fetches fresh market data from Kalshi API
3. User types → local filtering + ranking against cached markets
4. User selects result → trend data fetched lazily, detail panel shown
5. Enter key → opens market on kalshi.com in default browser

## Distribution
- Built `.app` lives in `dist/TruthPulse.app`
- Brand assets in `Assets/Brand/`

## Roadmap
- v0: macOS menu bar app (current)
- v1: Raycast extension + Windows system tray app
- Future: iOS Spotlight integration, Android widget
