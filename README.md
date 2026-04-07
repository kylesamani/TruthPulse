# TruthPulse

Instant search across all open Kalshi prediction markets. Live odds, trend data, keyboard-driven. Powered by Kalshi.

## Download

| Platform | Link |
|----------|------|
| **macOS** | [Download TruthPulse.dmg](https://github.com/kylesamani/TruthPulse/releases/latest/download/TruthPulse.dmg) |
| **Windows** | [Build from source](packages/windows) (see instructions below) |
| **Raycast** | [TruthPulse on Raycast Store](https://www.raycast.com/kyle_samani/truthpulse) |

## Features

- Search 10,000+ open prediction markets by title, category, or outcome
- Live odds displayed inline for every result
- Trend data (1D / 7D / 30D) with price delta
- Local cache for instant results, background sync with Kalshi API
- Open any market on kalshi.com with one keystroke
- Configurable global hotkey (default: Cmd+Shift+K on macOS, Ctrl+Shift+K on Windows)
- Configurable sync interval (1 min to 24 hours)
- macOS Spotlight integration (search markets from Spotlight)
- Windows PowerToys Run integration (search markets from PowerToys Run)

## Screenshots

*Coming soon*

## Source Code

Each platform is a self-contained implementation under `packages/`:

| Package | Stack |
|---------|-------|
| [`packages/mac`](packages/mac) | Swift 6 / SwiftUI / AppKit — macOS menu bar app + Spotlight |
| [`packages/windows`](packages/windows) | C# / WPF / .NET 8 — Windows system tray app + PowerToys Run plugin |
| [`packages/raycast`](packages/raycast) | TypeScript / React — Raycast extension |

## Build from source

### macOS

```bash
cd packages/mac
swift build
swift run TruthPulse
```

### Windows

**Prerequisites:** [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

```powershell
cd packages\windows
dotnet build
dotnet run --project TruthPulse
```

The app runs in the system tray. Use the global hotkey (default: Ctrl+Shift+K) to toggle the search window. Right-click the tray icon to change the hotkey, sync interval, check for updates, or quit.

### PowerToys Run Plugin

The PowerToys Run plugin lets you search Kalshi markets directly from the PowerToys Run launcher (Alt+Space by default).

**Prerequisites:**
- [PowerToys](https://github.com/microsoft/PowerToys/releases) v0.70+
- TruthPulse Windows app running (the plugin queries the app's local search API)

**Install:**

```powershell
cd packages\windows
powershell -ExecutionPolicy Bypass -File install-powertoys-plugin.ps1
```

Or manually:

```powershell
cd packages\windows
dotnet build PowerToysPlugin -c Release
Stop-Process -Name PowerToys -Force -ErrorAction SilentlyContinue
$dest = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins\TruthPulse"
New-Item -ItemType Directory -Path $dest -Force
Copy-Item "PowerToysPlugin\bin\Release\*" $dest -Recurse -Force
```

After installing, restart PowerToys and type `tp ` followed by your query:

```
tp tesla
tp fed rates
tp bitcoin
```

Press Enter on any result to open it on kalshi.com.

### Raycast

```bash
cd packages/raycast
npm install
npm run dev
```

## Architecture

```
packages/
├── mac/                    # macOS menu bar app (Swift/SwiftUI)
├── windows/
│   ├── TruthPulse/         # Windows system tray app (C#/WPF/.NET 8)
│   ├── PowerToysPlugin/    # PowerToys Run plugin (queries TruthPulse app)
│   └── TruthPulse.sln      # Visual Studio solution (both projects)
├── android/                # Android app (Kotlin/Jetpack Compose)
└── raycast/                # Raycast extension (TypeScript/React)
```

All platforms fetch directly from the [Kalshi public API](https://trading-api.readme.io/reference/getmarkets). No backend server required. Markets are cached locally for instant search, with configurable background refresh.

## License

MIT
