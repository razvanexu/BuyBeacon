# BuyBeacon — Frontend

Flutter mobile app for BuyBeacon, a location-aware shopping list. The user adds
product names; the backend resolves each to nearby shops, and the app
registers geofences so it can notify the user when they're near a relevant
store — even in the background. The map screen also shows all nearby shops as
live, distance-colored pins.

This is the `frontend/` half of the BuyBeacon monorepo. See the root
[`CLAUDE.md`](../CLAUDE.md) for the full project overview (backend included)
and its change history; this file covers frontend setup and structure only.

## Stack

- Flutter / Dart, Provider for state management
- Layered architecture: repository → orchestrator → provider → UI
- Local persistence: SQLite (`sqflite`)
- Location & geofencing: [Tracelet](https://github.com/Ikolvi/Tracelet)
  (`package:tracelet`)
- Maps: `google_maps_flutter`
- Notifications: `flutter_local_notifications`

## Project structure (`lib/`)

```
lib/
├── main.dart
├── models/            # Product, ShopLocation, AppLocation, AppGeofenceEvent,
│                       CategoryOption — the app's own domain types
├── repositories/       # product_repository.dart — combines local DB + remote API
├── providers/          # product_provider.dart — ChangeNotifier for the product list
├── orchestrators/       # shopping_orchestrator.dart — the "brain": reacts to product
│                       and location changes, drives geofences, retries, exposes state
├── services/
│   ├── database_service.dart              # local SQLite persistence
│   ├── api_service.dart                   # HTTP client to the Spring Boot backend
│   ├── location_service.dart              # live location via Tracelet
│   ├── geofence_service.dart              # geofence register/clear via Tracelet
│   ├── notification_decision_service.dart # debounce + "closest shop only" logic
│   ├── notification_service.dart          # push notification display
│   └── notification_channel_service.dart  # Android notification channel setup
├── screens/
│   ├── home_screen.dart   # product list + category picker
│   └── map_screen.dart    # GoogleMap with user location + color-coded shop pins
└── utils/
    └── debug_file_logger.dart  # temporary remote debug-log pipeline (see CLAUDE.md)
```

`AppLocation` and `AppGeofenceEvent` (in `models/`) are the app's own
location/geofence types — every file except `location_service.dart` and
`geofence_service.dart` depends on these rather than on Tracelet's own types,
so swapping the tracking plugin again only touches those two files.

## Setup

```
flutter pub get
```

Default backend URL is the LAN address `http://192.168.0.180:8080`
(`API_BASE_URL` in `services/api_service.dart`), used automatically for local
dev runs (`flutter run`).

## Building for on-device testing

To test against the home backend over the internet (Cloudflare Tunnel) rather
than the LAN default:

```
flutter build apk --release --dart-define=API_BASE_URL=https://api.cloudavenue.ro --dart-define=DEBUG_LOG_TOKEN=<token>
```

- `DEBUG_LOG_TOKEN` is optional — only needed while the temporary remote
  debug-log pipeline (`DebugFileLogger` → backend `/api/debug/log`) is still
  in use.
- Output: `build/app/outputs/flutter-apk/app-release.apk`.

**Getting the APK onto the test phone (POCO X7):**
- USB: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
  (`adb` at `C:\Users\razva\AppData\Local\Android\sdk\platform-tools\adb.exe`,
  not on `PATH`).
- Cable-free: both dev machine and phone (`poco-x7-pro`) are on the same
  Tailscale tailnet — `tailscale file cp <path-to-apk> poco-x7-pro:` (Taildrop),
  or right-click the APK in Explorer → "Send with Tailscale". Open the
  received file on the phone from the Tailscale notification and install it.

## Testing

```
flutter test                        # unit + widget tests
flutter test integration_test       # integration test (app_test.dart)
```

- `test/providers`, `test/services` — unit tests
- `test/screens` — widget tests
- `integration_test/app_test.dart` — full integration test
- Mocks are generated via `build_runner`/Mockito (`*.mocks.dart` files, regenerate
  with `dart run build_runner build --delete-conflicting-outputs` after
  changing a `@GenerateMocks` target)

## Known limitations / in-progress work

See [`CLAUDE.md`](../CLAUDE.md) — "Known Issues" and "Open Bugs" sections —
for the current state of geofence re-trigger flakiness, background GPS
throttling behavior, and other in-flight investigations. Don't duplicate that
tracking here; it's kept up to date in the root doc.
