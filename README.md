# TruthPulse

Instant search across all open Kalshi prediction markets. Live odds, trend data, keyboard-driven. Powered by Kalshi.

## Download

| Platform | Link |
|----------|------|
| **macOS** | [Download TruthPulse.dmg](https://github.com/kylesamani/TruthPulse/releases/latest/download/TruthPulse.dmg) |
| **Windows** | [Build from source](packages/windows) (untested — see instructions below) |
| **Raycast** | [TruthPulse on Raycast Store](https://www.raycast.com/kyle_samani/truthpulse) |

## Features

- Search 10,000+ open prediction markets by title, category, or outcome
- Live odds displayed inline for every result
- Trend data (1D / 7D / 30D) with price delta
- Local cache for instant results, background sync with Kalshi API
- Open any market on kalshi.com with one keystroke
- Configurable global hotkey (default: Cmd+Shift+K on macOS)

## Screenshots

*Coming soon*

## Source Code

Each platform is a self-contained implementation under `packages/`:

| Package | Stack |
|---------|-------|
| [`packages/mac`](packages/mac) | Swift 6 / SwiftUI / AppKit — macOS menu bar app |
| [`packages/windows`](packages/windows) | C# / WinUI 3 / .NET 8 — Windows system tray app |
| [`packages/raycast`](packages/raycast) | TypeScript / React — Raycast extension |

## Build from source

**macOS:**
```bash
cd packages/mac
swift build
swift run TruthPulse
```

**Windows:**
```bash
cd packages/windows
dotnet build
dotnet run --project TruthPulse
```

**Raycast:**
```bash
cd packages/raycast
npm install
npm run dev
```

## License

MIT
