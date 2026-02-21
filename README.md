# KC Gallery Viewer

Flutter app for browsing, searching, and downloading media from Kemono & Coomer mirrors with a polished gallery experience and multi‑platform support.

## Features
- Browse creators and posts with staggered grids, photo zoom, and video playback (Chewie/Better Player/WebView).
- Dual search: creators, tags, and Discord sources (server/channel search + test screen).
- Offline friendliness: cached media, scroll position memory, smart bookmarks/history, and download manager with permission handling.
- Theme & accessibility: light/dark themes, text scale control, and localized UI (Flutter localizations enabled).
- Analytics & stability: Firebase Analytics + Crashlytics hooks ready out of the box.

## Getting Started
Prerequisites:
- Flutter SDK ^3.10 (Dart 3.10) installed and on your PATH.
- Java/Android SDK for Android builds; Xcode for iOS/macOS; web/desktop targets require corresponding Flutter enablement.

Install dependencies:
```bash
flutter pub get
```

Run on a device/emulator:
```bash
flutter run
```

Build release (examples):
```bash
flutter build apk        # Android
flutter build web        # Web
flutter build windows    # Windows desktop
```

## Project Structure
- `lib/` – app source (providers, screens, widgets, services).
- `assets/` – bundled images/fonts/data.
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` – platform shells.
- `pubspec.yaml` – dependencies and assets.

## Configuration Notes
- No secrets are committed; Kemono/Coomer/Discord API endpoints are used directly. If you add API keys or private endpoints, keep them in `.env`/runtime config and out of git.
- Line endings: repo currently normalizes to Windows CRLF when touched by Git; this is safe.

## Contributing
1) Create a feature branch from `main`.
2) Format/analyze before committing: `flutter format . && flutter analyze`.
3) Open a PR with a short summary of changes and testing done.

## License
Not specified yet. Add a `LICENSE` file if you plan to distribute.
