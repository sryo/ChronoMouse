# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

ChronoMouse is a macOS utility that displays the current time next to the mouse cursor. The clock orbits around the cursor based on the current minute (like an analog clock hand), fades out when idle or typing, and reappears on mouse movement. Shows a battery bar when charge drops below 25%.

**Bundle ID:** `com.sryo.ChronoMouse`
**Deployment target:** macOS 13.0
**Build system:** Xcode project (no SPM, no external dependencies)
**Distribution:** Developer ID (not Mac App Store). No sandbox — the app requires a single Accessibility permission for global event monitoring; sandboxing it would split that into two TCC prompts (Accessibility + Input Monitoring) without meaningful security gain since the app already sees all keystrokes.

## Development Commands

```bash
# Build and run via Xcode
open ChronoMouse.xcodeproj

# Release build (archive + export + notarize)
./release.sh

# Notarize an existing build
./notarize.sh
```

Both scripts read configuration from `config.env` (team ID, keychain profile).

### Version Management

The app version is in the `VERSION` file at the project root. Sync to `MARKETING_VERSION` in Xcode build settings.

## Architecture

Pure AppKit application with no storyboard. Uses `main.swift` as entry point.

### Core Components

| File | Purpose |
|------|---------|
| `main.swift` | Single-instance enforcement via distributed notifications |
| `AppDelegate.swift` | Clock window setup, event monitors, battery polling, display updates |
| `MouseTracker.swift` | Transparent NSWindow that floats above all content, ignores mouse events |
| `BatteryBarView.swift` | Custom NSView drawing battery indicator (yellow <25%, red <10%) |
| `SettingsWindowController.swift` | Settings with launch-at-login checkbox (SMAppService) |
| `AppConstants.swift` | Centralized numeric constants (sizes, thresholds, timing) |

### Data Flow

1. `NSEvent.addGlobalMonitorForEvents` fires on mouse movement
2. `AppDelegate.updateDisplay()` reads current time, updates text and battery
3. `calculateWindowPosition()` places window on orbital path (minute-hand angle)
4. Delayed `fadeOut()` hides window after `fadeDelay` seconds (2s)
5. Typing or dragging triggers immediate fade-out

### Key Patterns

- **Accessory activation** (`.accessory`) - no dock icon, no menu bar
- **Screen-saver window level** - floats above everything including fullscreen
- **`canJoinAllSpaces`** - visible on all Spaces/desktops
- **Global event monitors** - tracks mouse, keyboard, modifiers without focus
- **IOKit power source** - direct battery reads via `IOPSCopyPowerSourcesInfo`
- **Option key** - holding Option shows minutes instead of hours

### Battery Display

- Polled every 60 seconds
- Below 25%: yellow bar above the time
- Below 10%: bar and text turn red
- While charging: color changes suppressed

## Important Notes

- `config.env` contains signing credentials - do not commit to public repos
- `build/` directory is gitignored (archive/export artifacts)
- No tests in this project currently

## Decisions

- **No telemetry, no crash reporting.** ChronoMouse is a tiny privacy-respecting utility. It does not phone home, does not collect usage data, and does not embed a crash reporter. If a crash ever needs investigation, ask users to share the macOS-native crash log from `~/Library/Logs/DiagnosticReports/`.
- **No sandbox** (see Distribution above).
- **Developer ID only**, not MAS — the global keystroke monitor would likely fail MAS review even if technically sandboxable.
