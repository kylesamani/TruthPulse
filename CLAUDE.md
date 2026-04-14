# TruthPulse

## What This Is
Instant search across all open Kalshi prediction markets. Live odds, trend data, keyboard-driven. Zero backend.

Available as a macOS menu bar app, iOS app, Android app, and Raycast extension (macOS + Windows).

## Repository Structure

```
packages/
├── mac/          # macOS + iOS (Swift/SwiftUI, shared package)
├── android/      # Android app (Kotlin/Jetpack Compose)
└── raycast/      # Raycast extension (TypeScript/React, macOS + Windows)
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

## Android App (`packages/android/`)

### Commands
- `cd packages/android && ./gradlew assembleDebug` -- Build debug APK
- `cd packages/android && ./gradlew assembleRelease` -- Build release APK
- `cd packages/android && ./gradlew installDebug` -- Install on connected device

### Stack
- **Language**: Kotlin 2.1
- **Platform**: Android 8+ (API 26)
- **UI**: Jetpack Compose + Material3
- **Networking**: OkHttp + kotlinx.serialization
- **Architecture**: MVVM (ViewModel + StateFlow)
- **Search**: AppSearch + Global Search ContentProvider

### Structure
```
packages/android/app/src/main/java/com/truthpulse/
├── TruthPulseApp.kt          # Application class
├── MainActivity.kt            # Single activity, Compose
├── data/
│   ├── KalshiApiClient.kt    # REST client (OkHttp + kotlinx.serialization)
│   ├── MarketModels.kt       # Data classes
│   ├── TrendModels.kt        # Trend data classes
│   ├── MarketCacheStore.kt   # JSON file cache
│   └── SynonymTable.kt       # Synonym loading + expansion
├── search/
│   ├── SearchService.kt      # Index + search + synonym expansion
│   ├── RankingPolicy.kt      # Multi-signal ranking
│   └── SearchIndexer.kt      # Global Search provider
└── ui/
    ├── SearchScreen.kt        # Main Compose screen
    ├── SearchViewModel.kt     # ViewModel with StateFlow
    ├── ResultRow.kt           # Market result composable
    ├── SparklineChart.kt      # Canvas-based sparkline
    └── TruthPulseTheme.kt    # Material3 theme with mint accent
```

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
- **Independent ports**: Each platform is self-contained, no shared code (macOS/iOS share a Swift package)
