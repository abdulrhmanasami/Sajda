# Sajda Pro

**A beautiful, native macOS menu bar application for Islamic prayer times.**

Sajda Pro lives in your menu bar and provides accurate prayer times, countdown to the next prayer, and configurable notifications — all in a sleek, native macOS interface.

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Platform](https://img.shields.io/badge/Platform-macOS-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar Integration** — Displays countdown or exact time for the next prayer directly in the menu bar
- **15+ Calculation Methods** — Including Umm al-Qura, ISNA, Muslim World League, Egyptian, and regional authorities
- **Multi-Language** — Full localization for English, Arabic (العربية), and Indonesian (Bahasa Indonesia)
- **Smart Location** — Automatic GPS detection or manual coordinate entry with search
- **Prayer Timer** — Configurable break alerts after prayer time passes
- **Notifications** — Native macOS notifications with customizable Adhan sounds
- **Launch at Login** — Seamless startup integration via `SMAppService`
- **Hanafi/Shafi'i** — Toggle between madhab calculation for Asr prayer
- **Manual Corrections** — Per-prayer minute adjustments for local fine-tuning
- **Wake-from-Sleep** — Automatically recalculates after macOS wakes from sleep

## Architecture

```
Sajda/
├── App/              Entry points & lifecycle (main, AppDelegate)
├── Models/           Data types & enums (CalculationMethod, AdhanSound, etc.)
├── Services/         Business logic (Prayer calculations, Location, Notifications)
├── ViewModels/       MVVM view models (PrayerTimeViewModel)
├── Views/            SwiftUI screens (Main, Settings, Onboarding, About)
├── Components/       Reusable UI (SajdaStepper, StyledToggle, VisualEffectView)
├── Extensions/       Swift extensions (NavigationAnimation, Notification.Name)
├── Utilities/        Helpers (AlertWindowManager)
├── Vendors/          Embedded libraries (FluidMenuBar, TimeZoneLocate)
└── Resources/        Assets, localization, entitlements
```

## Dependencies

| Package                                                             | Purpose                           |
| ------------------------------------------------------------------- | --------------------------------- |
| [Adhan](https://github.com/batoulapps/adhan-swift)                  | Prayer time calculation engine    |
| [NavigationStack](https://github.com/indieSoftware/NavigationStack) | Custom navigation with animations |

## Build & Run

```bash
# Clone
git clone https://github.com/abdulrhmanasami/Sajda.git
cd Sajda

# Build
xcodebuild build -project Sajda.xcodeproj -scheme Sajda -destination 'platform=macOS'

# Run tests
xcodebuild test -project Sajda.xcodeproj -scheme Sajda -destination 'platform=macOS' -only-testing:SajdaTests

# Open in Xcode
open Sajda.xcodeproj
```

## Requirements

- macOS 13.0+
- Xcode 15+
- Swift 5.9+
