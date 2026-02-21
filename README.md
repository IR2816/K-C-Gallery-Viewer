# KC Gallery Viewer

<p align="center">
  <img src="assets/images/Icon.png" alt="KC Gallery Viewer Icon" width="180" />
</p>

<p align="center">
  <strong>Cross-Platform Flutter Client for Kemono & Coomer Mirrors</strong><br/>
  High-performance gallery experience with search, download management, and offline support.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Web%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-lightgrey" />
  <img src="https://img.shields.io/badge/Status-Active-success" />
</p>

---

## Overview

**KC Gallery Viewer** is a multi-platform Flutter application designed to browse, search, and download media from Kemono and Coomer mirror services.

The application focuses on:

- Smooth gallery performance
- Clean and responsive UI
- Efficient caching and offline support
- Structured and scalable architecture

It is suitable for Android, Web, Desktop, and other Flutter-supported platforms.

---

## Key Features

### 1. Media Browsing
- Masonry / staggered grid layout optimized for image-heavy feeds
- Fullscreen image viewer with pinch-to-zoom
- Video playback via:
  - Chewie
  - Better Player
  - WebView fallback
- Infinite scrolling with scroll state persistence

### 2. Search & Discovery
- Creator search
- Tag filtering
- Discord source search (server & channel)
- Endpoint testing screen

### 3. Offline & Download Management
- Media caching
- Scroll position restoration
- Smart bookmarks
- Viewing history
- Integrated download manager
- Runtime permission handling (Android)

### 4. UI & Accessibility
- Light and Dark theme
- Dynamic text scaling
- Responsive layout (mobile, tablet, desktop)
- Flutter localization support

### 5. Stability & Observability
- Firebase Analytics hooks
- Firebase Crashlytics hooks
- Structured provider-based state management
- Separation of concerns (services, UI, state)

---

## Architecture

KC Gallery Viewer follows a modular layered architecture:

```
lib/
 ├── providers/        # State management (Provider)
 ├── services/         # API, caching, download services
 ├── screens/          # UI screens
 ├── widgets/          # Reusable components
 ├── models/           # Data models
 └── utils/            # Helpers and utilities
```

### Design Principles

- Clear separation between UI and business logic
- Service-driven data layer
- Provider-based state management
- Minimal platform-specific coupling
- Extensible for additional mirror platforms

---

## Technology Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter >= 3.10 |
| Language | Dart >= 3.10 |
| State Management | Provider |
| Media Playback | Chewie / Better Player / WebView |
| Networking | HTTP / Dio (depending on implementation) |
| Caching | Local storage / file system |
| Analytics | Firebase Analytics |
| Crash Reporting | Firebase Crashlytics |

---

## Platform Support

| Platform | Supported |
|----------|------------|
| Android | ✅ |
| Web | ✅ |
| Windows | ✅ |
| macOS | ✅ |
| Linux | ✅ |
| iOS | ✅ |

> Platform availability depends on local Flutter configuration.

---

## Installation

### Prerequisites

- Flutter SDK 3.10+
- Dart 3.10+
- Android SDK (for Android builds)
- Xcode (for iOS/macOS builds)
- Desktop/Web enabled via Flutter

Verify setup:

```bash
flutter doctor
```

---

### Clone Repository

```bash
git clone https://github.com/yourusername/kc-gallery-viewer.git
cd kc-gallery-viewer
```

---

### Install Dependencies

```bash
flutter pub get
```

---

## Running the Application

Run on connected device/emulator:

```bash
flutter run
```

Run on specific platform:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

---

## Building Release Versions

### Android

```bash
flutter build apk --release
```

### Web

```bash
flutter build web --release
```

### Windows

```bash
flutter build windows --release
```

### macOS

```bash
flutter build macos --release
```

### Linux

```bash
flutter build linux --release
```

### iOS

```bash
flutter build ios --release
```

---

## Configuration

### API Endpoints

The application directly consumes public Kemono and Coomer mirror endpoints.

No secrets are stored in the repository.

If adding private endpoints or API keys:

- Store them in `.env`
- Exclude via `.gitignore`
- Load at runtime

Example `.env` usage:

```
API_BASE_URL=https://example.com/api
```

---

## Third-Party Services

- Uses public Kemono & Coomer mirror APIs and optional Discord lookups; this client is not affiliated with any of those services.
- Users must follow each service’s Terms of Service, respect content ownership, and stay within any published rate limits.
- Do not commit private tokens or endpoints; keep them in environment variables or secure storage.

---

## Code Quality & Contribution

Before committing:

```bash
flutter format .
flutter analyze
```

### Branching Workflow

1. Create feature branch from `main`
2. Keep commits atomic
3. Open Pull Request with:
   - Change summary
   - Testing notes
   - Screenshots (if UI changes)

---

## Security Considerations

- No API keys committed
- No hardcoded secrets
- Permission requests handled at runtime
- File downloads use controlled directory access

---

## Performance Strategy

- Image caching
- Lazy loading
- Optimized grid rendering
- Scroll state preservation
- Reduced rebuild scope via Provider

---

## Roadmap

- Background download service
- Advanced filtering & sorting
- Media prefetch optimization
- Export/import settings
- Modular plugin system for new platforms
- Unit & integration test coverage expansion

---

## Known Limitations

- Public mirror availability depends on upstream services
- Desktop file permission models vary per OS
- Some video formats depend on platform codec support

---

## License

MIT License. See [`LICENSE`](LICENSE) for details.

---

## Disclaimer

This application is a third-party client and is not affiliated with, endorsed by, or officially connected to Kemono or Coomer.

Users are responsible for complying with applicable laws and content usage policies.

---

## Maintainer

Project maintained by:

**Your Name / Organization**

For issues, feature requests, or contributions, open a GitHub Issue or Pull Request.

---
