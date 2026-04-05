# TruthPulse

## What This Is
Instant search across all open Kalshi prediction markets. Live odds, trend data, keyboard-driven. Zero backend.

Available as a macOS menu bar app, Windows system tray app, and Raycast extension.

## Repository Structure

```
packages/
├── mac/          # macOS menu bar app (Swift/SwiftUI)
├── windows/      # Windows system tray app (C#/WinUI 3/.NET 8)
└── raycast/      # Raycast extension (TypeScript/React)
```

## macOS App (`packages/mac/`)

### Commands
- `cd packages/mac && swift build` — Build
- `cd packages/mac && swift run TruthPulse` — Run
- `cd packages/mac && swift test` — Test

### Stack
- **Language**: Swift 6.0
- **Platform**: macOS 14+ (Sonoma)
- **UI**: SwiftUI + AppKit (menu bar integration)
- **Package Manager**: Swift Package Manager (zero external dependencies)
- **API**: Kalshi public REST (`https://api.elections.kalshi.com/trade-api/v2`)
- **Concurrency**: Swift actors, async/await

### Structure
```
packages/mac/Sources/TruthPulse/
├── App/
│   ├── AppState.swift              # Central @Published state management
│   ├── TruthPulseAppDelegate.swift # Menu bar setup, popover, app lifecycle
│   └── GlobalHotkey.swift          # Configurable global keyboard shortcut
├── Features/Search/
│   ├── QuickSearchView.swift       # Main UI container (search + results)
│   ├── SearchFieldView.swift       # Input field with keyboard handling
│   ├── ResultRowView.swift         # Individual market result card
│   └── SparklineView.swift         # Trend sparkline chart
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

## Windows App (`packages/windows/`)

### Commands
- `cd packages/windows && dotnet build`
- `cd packages/windows && dotnet run --project TruthPulse`
- `cd packages/windows && dotnet publish -c Release -r win-x64 --self-contained`

### Stack
- C# / WinUI 3 / .NET 8, system tray with global hotkey

## Raycast Extension (`packages/raycast/`)

### Commands
- `cd packages/raycast && npm install && npm run dev`
- `cd packages/raycast && npm run build`
- `cd packages/raycast && npm run lint`

### Stack
- TypeScript/React, Raycast SDK, single-command extension

## Key Design Decisions
- **No backend**: All data fetched directly from Kalshi public API
- **Local search index**: Markets cached locally for instant typeahead
- **Lazy trend loading**: Candlestick data fetched on selection, not upfront
- **Field-aware ranking**: Title matches ranked higher than description matches, boosted by volume/liquidity
- **Three independent ports**: Each platform is self-contained, no shared code
