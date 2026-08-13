# BuyBeacon — Project Overview

Buy-reminder mobile app. Full architecture, current state, and known issues, as understood as of **2026-08-13** (post Places-migration + on-device bugfix passes + Tracelet migration). See also `GEMINI.md` (older session notes from a different assistant, still accurate for history predating this file) and `prd.md` (product requirements).

## What it does

BuyBeacon is a location-aware shopping list. The user adds product names to a list on their phone, picking a shop category the first time a given product name is seen. The backend finds nearby stores of that category, and sends coordinates back to the app. The app registers geofences around those coordinates and — even in the background — pushes a notification when the user walks/drives near a relevant store. The map screen also shows all nearby shops as color-coded pins (green = closest, yellow = near, red = further but still visible) that update live as the user moves.

Two repos, one Git root (`C:\Projects\BuyBeacon`):
- `frontend/` — Flutter (Dart) mobile app
- `backend/` — Java 21 / Spring Boot REST API

## Backend (`backend/`)

Spring Boot app, Maven (`pom.xml`).

**Request flow for `POST /api/shops/find`:**
1. `ShopFinderController` receives `ProductSearchRequestDto` (`products: List<String>`, optional `latitude`/`longitude`) and delegates to `ShopFinderService`.
2. `ShopFinderServiceImp` — core orchestration, per product (concurrently, via bounded `scrapingExecutor`), calls `findShopsForProduct`:
   - `WebSearchServiceImp` looks up the product's crowdsourced category (`ProductCategoryService`, falls back to generic `"store"` if unknown) and runs a **Google Places Nearby Search** (`GooglePlacesClient.findNearbyPlaces`, `rankby=distance`) for that Places type near the user's coordinates. Handles the `supermarket` / `grocery_or_supermarket` type overlap by querying both synonyms.
   - Separately, checks the hardcoded list `ENRICHMENT_RETAILERS = ["Carrefour"]` against `ScraperOrchestrator` (only `CarrefourScraper` is implemented) to confirm real product availability; adds the retailer as a nameless candidate if it matches (no coordinates — resolved later via geocoding).
   - Merges candidates by shop name → associated products.
   - Resolves each shop to final coordinates (`resolveShop`): uses the Nearby Search coordinates directly if already known, otherwise geocodes by name via Places Text Search (`GooglePlacesClient.findPlaces`, biased by lat/lng, takes only the top/closest result to avoid one chain flooding results with every branch).
3. Returns the deduplicated `List<ShopResponseDto>` to the frontend.

**Category flow (`/api/products/category`, `/api/products/categories`)** — `ProductCategoryController`:
- `GET /api/products/category?product=X` — frontend checks if a product name is already categorized before adding it.
- `POST /api/products/category` — frontend submits the user's category pick for a new product name.
- `GET /api/products/categories` — fixed list of pickable categories, from the `PlacesCategory` enum (`model/PlacesCategory.java`): supermarket, hardware_store, pharmacy, electronics_store, clothing_store, pet_store, book_store, store (generic fallback). Each maps 1:1 to a real Google Places `type`.
- Persistence: `ProductCategoryServiceImp` normalizes the product name (diacritics stripped, lowercased) and stores via `ProductCategoryStore` → `JpaProductCategoryStore` → `ProductCategorySubmission` JPA entity (a small shared/crowdsourced dictionary, not per-user).

**Key backend files:**
- `controller/ShopFinderController.java` — main shop-discovery endpoint
- `controller/ProductCategoryController.java` — category lookup/save/list endpoints
- `controller/ScraperController.java` — debug endpoint `GET /api/scrape/products?query=&retailerName=`, calls `ScraperOrchestrator` directly
- `controller/DebugLogController.java` — **temporary**, in-memory ring-buffer sink at `/api/debug/log` (`POST` to append, `GET` to read, `DELETE` to clear) for the frontend's `DebugFileLogger` to stream logs over the internet during the location-tracking investigation (see frontend History below). Requires header `X-Debug-Token` matching env var `DEBUG_LOG_TOKEN` (set in `backend/.env`, **not** committed) — refuses all requests if that env var is unset, since the backend is publicly reachable via the Cloudflare Tunnel. Remove once the investigation is closed out.
- `service/ShopFinderServiceImp.java` — core orchestration logic
- `service/WebSearchServiceImp.java` — category-based Places Nearby Search discovery (**no longer scrapes Google search** — see History below)
- `service/ProductCategoryServiceImp.java` / `ProductCategoryStore` / `JpaProductCategoryStore` — category dictionary
- `client/GooglePlacesClient.java` — both Places Text Search (`findPlaces`, geocoding by name) and Nearby Search (`findNearbyPlaces`, category-based discovery)
- `scraper/orchestration/ScraperOrchestrator.java` — dispatches to the right `RetailerScraper` by name
- `scraper/retailers/CarrefourScraper.java` — only concrete retailer scraper; scrapes `carrefour.ro`, used only for availability confirmation now, not shop discovery
- `scraper/common/SeleniumHtmlFetcher.java` / `JSoupHtmlFetcher.java` / `JSoupHtmlParser.java` — still used by `CarrefourScraper`'s scraping path; no longer used for shop discovery (that Google-search-scraping path is gone)

**Unused / dead code worth knowing about:**
- `service/GeocodingService.java` (interface) + `service/NominatimGeocodingServiceImp.java` (OpenStreetMap Nominatim) + `service/MockGeocodingServiceImp.java` — an alternate geocoding path, never wired into `ShopFinderServiceImp` (which uses `GooglePlacesClient` directly). Predates the current design; not deleted.
- `service/MockWebSearchServiceImp.java` — `@Profile("test")` stub, returns hardcoded shop names for tests.

**Deployment note:** backend + a Selenium container run on the user's own machine at home, exposed via a **Cloudflare Tunnel** at `https://api.cloudavenue.ro`. The tunnel only affects *inbound* traffic reaching the backend from the internet — outbound requests (backend/Selenium → Google Places/Carrefour) go out over the home ISP connection, not through Cloudflare.

## Frontend (`frontend/`)

Flutter app, Provider state management, layered/SOLID architecture (repository → orchestrator → provider → UI).

**Architecture:**
- `services/database_service.dart` — local SQLite persistence of the product list
- `services/api_service.dart` — singleton HTTP client to the Spring Boot backend (`API_BASE_URL`, default `http://192.168.0.180:8080`, overridden in real builds via `--dart-define=API_BASE_URL=https://api.cloudavenue.ro`); also backs the category lookup/save/list endpoints
- `repositories/product_repository.dart` — combines local DB (products) + remote API (shop lookup + category lookup/save); no business logic
- `providers/product_provider.dart` — `ChangeNotifier` holding the product list; add/delete/load, delegates persistence to the repository; exposes an `onProductsChanged` callback rather than owning geofence/network logic itself
- `models/category_option.dart` — category picker option model, mirrors backend `PlacesCategory`
- `orchestrators/shopping_orchestrator.dart` — the "brain": listens to product-list changes *and* to location changes (re-fetches shops when the user has moved ≥300m since the last fetch, throttled to once per 30s — see History below), updates geofences, exponential-backoff retry on backend connection errors, emits a state stream (`isLoading`, `hasConnectionError`, `shopLocations`)
- `models/app_location.dart` / `models/app_geofence_event.dart` — the app's own location/geofence-event types (`AppLocation`: latitude, longitude, accuracy, isMoving; `AppGeofenceEvent`: identifier + `GeofenceAction` enum). Everything except `LocationService`/`GeofenceService` depends on these, not on the tracking plugin's own types — swapping the plugin again (see History below) only touches those two files. Deliberate Dependency-Inversion boundary, added during the Tracelet migration.
- `services/location_service.dart` — live user location via **Tracelet** (`package:tracelet`); only file besides `geofence_service.dart` allowed to import it. `AndroidConfig.locationUpdateInterval`/`fastestLocationUpdateInterval` set explicitly; calls `Tracelet.changePace(true)` after `.ready()`/`.start()` as a safety net in case a device's automatic stationary/moving detection doesn't engage
- `services/geofence_service.dart` — registers/clears geofences from coordinates via Tracelet, exposes a stream of `AppGeofenceEvent` (no decision logic)
- `services/notification_decision_service.dart` — debouncing (5s) + "notify only for the closest store among newly-entered geofences" decision logic
- `services/notification_service.dart` / `notification_channel_service.dart` — push notification display + Android channel setup; requests `POST_NOTIFICATIONS` at runtime. `flutter_local_notifications` v22's `initialize()`/`show()` take named parameters (`settings:`, `id:`, `title:`, etc.) — positional-arg calls from v19 no longer compile.
- `screens/home_screen.dart` — product list UI; prompts a category picker when adding a product name the backend doesn't already recognize
- `screens/map_screen.dart` — `GoogleMap` with the user's location and shop markers, colored green (closest)/yellow (≤500m)/red (≤1000m) by live-computed distance, recalculated on every location update — independent of native geofence ENTER/EXIT events
- `utils/debug_file_logger.dart` — `DebugFileLogger` singleton, appends timestamped lines to (a) the app's **external** files dir (`getExternalStorageDirectory()`, not internal `/data/data` — that requires root or a debuggable build to `adb pull`, and release builds aren't debuggable) as `buybeacon_debug_log.txt`, and (b) `POST`s the same line to the backend's temporary `/api/debug/log` sink over the internet, for near-real-time viewing without a live adb/Wi-Fi session (see backend's `DebugLogController`). Not gated by `kDebugMode` — runs in release builds too. Remote posting needs `--dart-define=DEBUG_LOG_TOKEN=<token>` at build time matching the backend's `DEBUG_LOG_TOKEN` env var, else it silently no-ops. Retrieve the local file after a walk via `adb pull /storage/emulated/0/Android/data/com.buy_beacon.frontend/files/buybeacon_debug_log.txt`. **Temporary tooling** built for the location-tracking investigation below — remove alongside `DebugLogController` once no longer needed.

**Testing:** integration test (`integration_test/app_test.dart`), widget tests (`test/screens`), unit tests (`test/providers`, `test/services`). Backend has unit tests (Mockito) for `ShopFinderService`, `CarrefourScraper`, `JSoupHtmlParser`, plus `MockMvc` controller tests.

**Release build command** (used for real on-device testing against the home backend, not the LAN-default URL):
```
flutter build apk --release --dart-define=API_BASE_URL=https://api.cloudavenue.ro --dart-define=DEBUG_LOG_TOKEN=<token>
```
`DEBUG_LOG_TOKEN` is optional (only needed while the temporary remote debug-log pipeline is in use, see History above — matches backend's `.env` `DEBUG_LOG_TOKEN`) and can be dropped once that's removed. Output: `build/app/outputs/flutter-apk/app-release.apk`. Test device (POCO X7, MIUI/HyperOS) — `adb` is available via the Android SDK at `C:\Users\razva\AppData\Local\Android\sdk\platform-tools\adb.exe` (not on `PATH`); USB debugging has been enabled on-device for this investigation, so `adb install -r` works directly, no manual sideload needed.

## History: Google-search scraping → Places-based discovery (resolved)

Originally, shop discovery scraped `google.com/search` (Selenium + JSoup), which Google actively blocked with an anti-bot JS-challenge page — confirmed from both a sandbox IP and the user's home IP. Because the only retailer-scraper fallback was Carrefour, every product search degraded to a single "Carrefour Express" pin.

**Fix, implemented and merged (PR #2, `feature/shop-discovery-places-text-search-migration`):** replaced the scraping path in `WebSearchServiceImp` with **category-based Google Places Nearby Search**, using a new crowdsourced product→category dictionary (`ProductCategoryService` + `PlacesCategory` enum) instead of free-text product name matching (Places has no notion of "sells product X", only place types). Bundled into the same release: distance-based yellow/red map pins (previously only green "nearest" pins existed) and the category-picker UI flow for uncategorized products. `CarrefourScraper` and Selenium remain, now used only for availability *confirmation*, not discovery.

## History: flutter_background_geolocation → Tracelet migration (resolved)

Extensive on-device debugging (permissions, MIUI battery settings, `changePace(true)`, custom native-log dumping — see Known Issues below for the full diagnostic trail) eventually traced total absence of continuous location tracking to `flutter_background_geolocation` requiring a **paid Transistorsoft license** ($500/app) that was never purchased/configured; the plugin silently disables its tracking engine without one (`LICENSE VALIDATION FAILURE` in logcat, swallowed as unhandled exceptions in Dart). Confirmed via `adb logcat`, not visible from Dart-level code or the plugin's own Flutter-side API.

**Decision: migrate to [Tracelet](https://github.com/Ikolvi/Tracelet)** (`package:tracelet`, Apache 2.0, free, open-source, active — ~7k downloads/month as of mid-2026), a near-drop-in-concept alternative with equivalent geofencing/motion-detection/persistence/headless-execution features, plus a built-in `getSettingsHealth()` diagnostic (`isAggressiveOem` flag + `showPowerManager()` to jump straight to the OEM battery-whitelist screen — would have shortcut much of this session's manual MIUI hunting).

**What changed:**
- `LocationService`/`GeofenceService` rewritten against `package:tracelet` instead of `package:flutter_background_geolocation`. Per explicit instruction, this was also used as an opportunity to fix the underlying coupling problem: added `models/app_location.dart` (`AppLocation`) and `models/app_geofence_event.dart` (`AppGeofenceEvent`) as the app's own domain types, translated at the `LocationService`/`GeofenceService` boundary. Every other file (`map_screen.dart`, `notification_decision_service.dart`, `shopping_orchestrator.dart`, tests) depends only on these — a plugin swap again would only touch the two service files, not ripple through the app (Dependency Inversion).
- `AndroidManifest.xml`'s `android.permission.ACTIVITY_RECOGNITION` addition (from the misdiagnosis, see Known Issues) is harmless and was left in place — Tracelet also needs it, and it auto-merges the rest of its required permissions via its own AAR manifest, no other manual manifest changes needed.
- Toolchain forced upgrades to unblock the new dependency's SDK floor (`tracelet` requires Dart `^3.10.3`): Flutter `3.32.5 → 3.47.0` (`flutter upgrade --force`, needed since the SDK checkout's git branch had diverged from `origin/stable` — harmless, no user work was on that branch), Gradle `8.12 → 9.1.0`, AGP `8.7.3 → 8.11.1`, Kotlin `2.1.0 → 2.2.20`, NDK `27.0.12077973 → 28.2.13676358`. Also removed stale `flutter_background_geolocation`/`background_fetch` project references from `android/build.gradle.kts` and `android/app/build.gradle.kts` (manual Gradle wiring the old plugin required, now dead and blocking the build with "project not found" once the plugin was removed from `pubspec.yaml`).
- `flutter pub upgrade --major-versions` (needed to fix an unrelated `analyzer`-too-old-for-Dart-3.13-syntax crash in `build_runner`/mockito codegen) pulled in `flutter_local_notifications` v22 as a side effect, which has breaking API changes (`initialize()`/`show()` switched from positional to named parameters) — fixed in `notification_service.dart`.
- Test mocks: `flutter_background_geolocation`'s raw `MethodChannel` mocking (`test/services/location_service_test.dart`, `test/services/geofence_service_test.dart`) replaced with Tracelet's supported test seam — `TraceletPlatform.instance = mockPlatform` (a `PlatformInterface` subclass), generated via Mockito's `@GenerateMocks(customMocks: [MockSpec<TraceletPlatform>(...)])`. Note: generating the mock with `MockSpec`'s `mixingIn:` parameter crashes mockito 5.8.1's builder (`Null check operator used on a null value` in `_mockTargetFromMockSpec`) — worked around by generating a plain mock and manually declaring `class MockTraceletPlatform extends GeneratedMockTraceletPlatform with MockPlatformInterfaceMixin {}` instead.
- Added a temporary debug-log pipeline (frontend `DebugFileLogger` → backend `DebugLogController` at `/api/debug/log`) so on-device logs could be inspected without a live adb/Wi-Fi session during the long walk-test iteration cycle — see both files' entries above. Meant to be removed once this investigation is fully closed out.

**Two more crashes surfaced and fixed after the migration itself was otherwise working, both on a fresh (permissions-reset) install:**
1. `Tracelet.start()`/`changePace()` threw `PlatformException(PERMISSION_DENIED)` when called before location permission was granted — harmless in Dart (unhandled but non-fatal), *except* that the underlying attempt to start a location-type foreground service without the permission makes Android 14+ throw `CannotPostForegroundServiceNotificationException` and force-kill the whole app (`ActivityManager: ... crashed too many times, killing!` in logcat) — not a Dart-catchable failure. **Fixed**: `LocationService.initialize()` now calls `Tracelet.requestLocationAuthorization()` / `requestNotificationAuthorization()` first and only proceeds to `ready()`/`start()` if not `AuthorizationStatus.denied`.
2. Even with permission granted, the *same* `CannotPostForegroundServiceNotificationException` crash persisted — root cause: `ForegroundServiceConfig` never set `notificationSmallIcon`, so Android rejected the notification outright (same class of bug hit with the old plugin's default `ic_launcher` mipmap being full-color, invalid for a status-bar icon). **Fixed**: explicitly set `notificationSmallIcon: 'ic_stat_notify'` (the same flat/alpha-masked drawable used before).

**Status as of this writing: RESOLVED, confirmed on-device.** Remote debug log (`/api/debug/log`) showed continuous `LocationService._onLocation` entries every 3-7 seconds with real GPS accuracy (6-12m, not the old 100m coarse fixes) while the app sat stationary — the underlying tracking engine is alive and sampling continuously now, unlike every attempt with the old plugin. Map pin colors also visually confirmed live-updating (user standing between two shops, watching color flip with GPS jitter). **Still pending**: an actual walk test (300m+) to confirm `ShoppingOrchestrator`'s refetch-on-movement logic triggers correctly with real position change, planned for the next morning.

## Known Issues

### Map/shop list never refreshed while roaming (fixed 2026-08-13, verified needs on-device retest)

On-device retest of the 2026-08-12 notification/pin-color fixes (below) surfaced a deeper bug: while walking, no new shops ever appeared on the map, a shop already 1.2km away stayed visible, and pin colors never changed — only the user's own blue dot (drawn natively by the Google Maps SDK via `myLocationEnabled: true`, independent of the app's location plugin) moved.

**Root cause #1 (confirmed, fixed):** `ShoppingOrchestrator` only re-queried the backend for shops on `ProductProvider.onProductsChanged` — never in response to location changes. `shopLocations` was frozen at whatever it was when the product list was last edited, regardless of how far the user roamed. **Fixed**: added a `LocationService` listener (`_onLocationChanged`) that re-triggers `_fetchProductsAndShops()` once the user has moved ≥300m since the last fetch, throttled to at most once per 30s.

**Root cause #2 — misdiagnosed, then finally found (2026-08-13, see History section below for the full chase):** repeated on-device walk tests kept showing zero continuous `onLocation` events — only one-shot fixes at app startup — no matter what was tried: full permission grants (including `ACTIVITY_RECOGNITION`, initially suspected as the culprit), disabling MIUI battery restrictions, forcing `changePace(true)`. The **actual** root cause, found via `adb logcat`: `flutter_background_geolocation` is a commercial (Transistorsoft) plugin requiring a paid license key in `AndroidManifest.xml` ($500/app) — without one, the native engine logs `LICENSE VALIDATION FAILURE` and disables itself at startup, silently swallowing `start()`/`changePace()` calls as unhandled `PlatformException`s. Every other fix in this session was necessary-but-not-sufficient; none of them could have worked. **Resolved by migrating off the plugin entirely** — see History below.

### Notifications and pin-color fixes (fixed 2026-08-12, verified needs on-device retest)

Two bugs surfaced during physical-device testing (POCO X7) right after the Places migration:

1. **Notifications never fired (no sound, no vibration).** Root cause: `AndroidManifest.xml` never declared `android.permission.POST_NOTIFICATIONS`, and `NotificationService.initialize()` never requested it at runtime — required on Android 13+, otherwise `flutter_local_notifications`'s `.show()` silently no-ops. **Fixed**: added the manifest permission + `androidPlugin?.requestNotificationsPermission()` call. Requires a fresh reinstall (sideloaded APK) to take effect; MIUI's own background/battery restrictions are a separate, not-yet-hit variable to watch if the fix doesn't fully resolve it on retest.
2. **Map pin colors lagged real position.** Root cause: `distanceFilter: 0.0` alone left `flutter_background_geolocation` on default (slower) Android location-batching intervals. **Fixed**: added explicit `locationUpdateInterval: 3000` / `fastestLocationUpdateInterval: 1000`. The marker-recoloring logic itself (`map_screen.dart:_createShopMarkers`) was already correct — it recomputes on every location update; the issue was purely update frequency.

### Deferred: geofence "already inside" edge case (known, not fixed — explicit user decision to leave as-is for now)

`geofenceInitialTriggerEntry: true` only evaluates once, at the moment a geofence is registered, and needs a fresh GPS fix at that instant. If the user is already inside a shop's 500m radius when `ShoppingOrchestrator` calls `addGeofences()` (e.g. search finishes while already indoors near that shop), no ENTER event fires and no notification is ever sent for that shop — silently, until the user exits and re-enters.

Crossing an actual geofence boundary while moving works correctly (verified by tracing the code): it's a real native transition, independent of the fragile initial-evaluation path, and correctly produces a fresh notification for the newly-entered shop even while still inside another shop's overlapping geofence.

**Proposed fix (not implemented — user said "leave it for now", 2026-08-12):** after `addGeofences()`, explicitly compute distance to each newly-added shop and manually inject an ENTER-equivalent into `NotificationDecisionService` for any shop already within radius, instead of relying solely on the native initial-trigger evaluation.

## Useful pointers

- Diagrams: `Diagrams/` (`backend_flowchart.mmd`, `sequence_notification.mmd`, `v1_architecture.mmd`, etc.) — **may be stale** relative to the Places-based discovery flow described above; verify against current code before trusting them.
- Older rolling session notes (Gemini-authored, still relevant history predating this file): `GEMINI.md`
- Product requirements: `prd.md`
