# TruthPulse

Instant search across all open Kalshi prediction markets. Live odds, trend data, keyboard-driven. Powered by Kalshi.

## Download

| Platform | Download |
|----------|----------|
| **macOS** | [TruthPulse.dmg](https://github.com/kylesamani/TruthPulse/releases/latest/download/TruthPulse.dmg) |
| **iOS** | App Store (coming soon) |
| **Windows** | [TruthPulse-windows.zip](https://github.com/kylesamani/TruthPulse/releases/latest/download/TruthPulse-windows.zip) |
| ↳ PowerToys Run | [TruthPulse-powertoys.zip](https://github.com/kylesamani/TruthPulse/releases/latest/download/TruthPulse-powertoys.zip) |
| **Android** | [TruthPulse-android.apk](https://github.com/kylesamani/TruthPulse/releases/latest/download/TruthPulse-android.apk) |
| **Raycast** | [Raycast Store](https://www.raycast.com/kyle_samani/truthpulse) |

## Features

- Search 40,000+ open prediction markets by title, category, or outcome
- Live odds displayed inline for every result
- Trend data (1D / 7D / 30D) with sparkline charts and price delta
- Synonym expansion ("fed" matches "federal reserve", "btc" matches "bitcoin")
- Local cache for instant results, background sync with Kalshi API
- Open any market on kalshi.com with one keystroke/tap
- OS-native search integration on every platform:
  - **macOS**: Spotlight (search markets from Spotlight)
  - **iOS**: Spotlight (search markets from Spotlight)
  - **Windows**: PowerToys Run (search markets from Alt+Space)
  - **Android**: AppSearch (search markets from OEM launcher search)
- Configurable global hotkey (macOS: Cmd+Shift+K, Windows: Ctrl+Shift+K)

## Platforms

### macOS (menu bar app)

Sits in your menu bar. Click the icon or press the global hotkey to search.

```bash
cd packages/mac
swift build
swift run TruthPulse
```

Requires macOS 14+ (Sonoma). No external dependencies.

### iOS

Native iPhone and iPad app with Spotlight integration. Tap any result to open the market on kalshi.com in an in-app browser.

```bash
cd packages/mac
swift build
```

The iOS target is part of the shared Swift package. Open in Xcode to build and run on a device or simulator. Requires iOS 17+.

### Windows (system tray app)

Runs in the system tray. Right-click the tray icon to configure hotkey, sync interval, or quit.

```powershell
cd packages\windows
dotnet build
dotnet run --project TruthPulse
```

Requires [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).

#### PowerToys Run Plugin

Search Kalshi markets from the PowerToys Run launcher (Alt+Space).

```powershell
cd packages\windows
powershell -ExecutionPolicy Bypass -File install-powertoys-plugin.ps1
```

Requires [PowerToys](https://github.com/microsoft/PowerToys/releases) v0.70+ and the TruthPulse Windows app running. Type `tp ` followed by your query.

### Android

Native Android app with Material 3 design. Integrates with Android AppSearch for OEM launcher search (Samsung, OnePlus, etc.) and legacy Global Search for older devices.

```bash
cd packages/android
./gradlew assembleDebug
./gradlew installDebug   # install on connected device/emulator
```

Requires Android SDK 35 and JDK 17+. Target: Android 8+ (API 26).

### Raycast

```bash
cd packages/raycast
npm install
npm run dev
```

Also available on the [Raycast Store](https://www.raycast.com/kyle_samani/truthpulse).

## Architecture

```
packages/
├── shared/                 # Shared synonym table (synonyms.json)
├── mac/                    # macOS + iOS (Swift/SwiftUI, shared package)
│   └── Sources/
│       ├── TruthPulseCore/ # Shared business logic (models, services, ranking)
│       ├── TruthPulse/     # macOS menu bar app
│       └── TruthPulseIOS/  # iOS app
├── windows/
│   ├── TruthPulse/         # Windows system tray app (C#/WPF/.NET 8)
│   └── PowerToysPlugin/    # PowerToys Run plugin
├── android/                # Android app (Kotlin/Jetpack Compose)
└── raycast/                # Raycast extension (TypeScript/React)
```

All platforms fetch directly from the [Kalshi public API](https://trading-api.readme.io/reference/getmarkets). No backend server required. Markets are cached locally for instant search, with configurable background refresh.

### How search works

1. On launch, fetch all open markets from Kalshi (cursor-paginated, ~40K markets)
2. Build a local search index with normalized text (diacritics stripped, lowercased)
3. On keystroke (4-char minimum, 80ms debounce): two-pass filter (phrase match, then all-tokens-present)
4. Rank results using field-weighted text scoring + market signals (liquidity, volume, open interest, recency)
5. Expand queries with synonym table ("fed" also searches "federal reserve", "fomc")
6. Trend data (candlestick charts) loaded lazily on result selection

### OS search integration

Each platform indexes markets into the OS search infrastructure so users can find prediction market odds without opening the app:

| Platform | API | What happens |
|----------|-----|-------------|
| macOS | Core Spotlight | Markets appear in Spotlight results with odds |
| iOS | Core Spotlight | Markets appear in Spotlight results with odds |
| Windows | PowerToys Run plugin | Type `tp query` in PowerToys Run |
| Android | AppSearch PlatformStorage | Markets appear in OEM launcher search |
| Android | ContentProvider (legacy) | Fallback for older launchers |

## License

MIT
