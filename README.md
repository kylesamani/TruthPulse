# Kalshi Quick Search

Native macOS-first quick lookup for live Kalshi markets.

## What is implemented

- Native SwiftUI app with both:
  - a launch window that opens directly into search
  - a macOS menu bar extra for fast re-access
- Direct Kalshi REST integration with no backend
- Local SQLite + FTS5 search index for open markets
- Search ranking that blends:
  - title and outcome relevance
  - event and description matching
  - liquidity / volume / recency signals
- Keyboard-first search flow:
  - up/down arrows change selection
  - return opens the selected market in the default browser
- Result rows with:
  - current odds
  - rich media when available
  - compact sparkline
- Detail rail with:
  - `1D / 7D / 30D` selector
  - larger trend view
  - open-in-browser action
- Polling refresh and lazy trend fetching
- Disk-backed image cache

## Run locally

Open `Package.swift` in Xcode, then run the `KalshiQuickSearchApp` executable target.

From Terminal:

```bash
swift build
swift run KalshiQuickSearchApp
```

## Current notes

- The app uses Kalshi public REST endpoints and assumes public market data remains accessible without API auth.
- The search index stores only `open` markets.
- URL handling uses Kalshi-provided URLs when present, with a Kalshi browse fallback when a direct page URL is unavailable.
- The current app is implemented as a Swift package for fast setup. If we want a polished distributable `.app` with background-only menu bar behavior, the next step is to promote this into a full Xcode app target with bundle metadata and launch-agent polish.
