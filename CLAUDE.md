# BuyBeacon — Project Overview

Buy-reminder mobile app. Full architecture, current state, and known issues, as understood as of **2026-08-13** (post Places-migration + on-device bugfix passes). See also `GEMINI.md` (older session notes from a different assistant, still accurate for history predating this file) and `prd.md` (product requirements).

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
- `orchestrators/shopping_orchestrator.dart` — the "brain": listens to product-list changes *and* to location changes (re-fetches shops when the user has moved ≥300m since the last fetch, throttled to once per 30s — see Fixes below), updates geofences, exponential-backoff retry on backend connection errors, emits a state stream (`isLoading`, `hasConnectionError`, `shopLocations`)
- `services/location_service.dart` — live user location via `flutter_background_geolocation`; `locationUpdateInterval`/`fastestLocationUpdateInterval` set explicitly (see Fixes below)
- `services/geofence_service.dart` — registers/clears geofences from coordinates, exposes a stream of raw enter/exit events (no decision logic)
- `services/notification_decision_service.dart` — debouncing (5s) + "notify only for the closest store among newly-entered geofences" decision logic
- `services/notification_service.dart` / `notification_channel_service.dart` — push notification display + Android channel setup; now requests `POST_NOTIFICATIONS` at runtime (see Fixes below)
- `screens/home_screen.dart` — product list UI; prompts a category picker when adding a product name the backend doesn't already recognize
- `screens/map_screen.dart` — `GoogleMap` with the user's location and shop markers, colored green (closest)/yellow (≤500m)/red (≤1000m) by live-computed distance, recalculated on every location update — independent of native geofence ENTER/EXIT events
- `utils/debug_file_logger.dart` — `DebugFileLogger` singleton, appends timestamped lines to the app's **external** files dir (`getExternalStorageDirectory()`, not internal `/data/data` — that requires root or a debuggable build to `adb pull`, and release builds aren't debuggable) as `buybeacon_debug_log.txt`; used for on-device diagnosis when no live adb session is available (e.g. testing while walking outside Wi-Fi/USB range). Not gated by `kDebugMode` — runs in release builds too. Wired into `LocationService._onLocation`, `GeofenceService._onGeofence`, and `ShoppingOrchestrator._onLocationChanged`/`_fetchProductsAndShops`. Retrieve after a walk via `adb pull /storage/emulated/0/Android/data/com.buy_beacon.frontend/files/buybeacon_debug_log.txt` once reconnected.

**Testing:** integration test (`integration_test/app_test.dart`), widget tests (`test/screens`), unit tests (`test/providers`, `test/services`). Backend has unit tests (Mockito) for `ShopFinderService`, `CarrefourScraper`, `JSoupHtmlParser`, plus `MockMvc` controller tests.

**Release build command** (used for real on-device testing against the home backend, not the LAN-default URL):
```
flutter build apk --release --dart-define=API_BASE_URL=https://api.cloudavenue.ro
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. Test device (POCO X7, MIUI/HyperOS) has no `adb`/USB debugging set up on this dev machine — install by copying the APK and sideloading manually, not `flutter run`.

## History: Google-search scraping → Places-based discovery (resolved)

Originally, shop discovery scraped `google.com/search` (Selenium + JSoup), which Google actively blocked with an anti-bot JS-challenge page — confirmed from both a sandbox IP and the user's home IP. Because the only retailer-scraper fallback was Carrefour, every product search degraded to a single "Carrefour Express" pin.

**Fix, implemented and merged (PR #2, `feature/shop-discovery-places-text-search-migration`):** replaced the scraping path in `WebSearchServiceImp` with **category-based Google Places Nearby Search**, using a new crowdsourced product→category dictionary (`ProductCategoryService` + `PlacesCategory` enum) instead of free-text product name matching (Places has no notion of "sells product X", only place types). Bundled into the same release: distance-based yellow/red map pins (previously only green "nearest" pins existed) and the category-picker UI flow for uncategorized products. `CarrefourScraper` and Selenium remain, now used only for availability *confirmation*, not discovery.

## Known Issues

### Map/shop list never refreshed while roaming (fixed 2026-08-13, verified needs on-device retest)

On-device retest of the 2026-08-12 notification/pin-color fixes (below) surfaced a deeper bug: while walking, no new shops ever appeared on the map, a shop already 1.2km away stayed visible, and pin colors never changed — only the user's own blue dot (drawn natively by the Google Maps SDK via `myLocationEnabled: true`, independent of the app's location plugin) moved.

**Root cause #1 (confirmed, fixed):** `ShoppingOrchestrator` only re-queried the backend for shops on `ProductProvider.onProductsChanged` — never in response to location changes. `shopLocations` was frozen at whatever it was when the product list was last edited, regardless of how far the user roamed. **Fixed**: added a `LocationService` listener (`_onLocationChanged`) that re-triggers `_fetchProductsAndShops()` once the user has moved ≥300m since the last fetch, throttled to at most once per 30s.

**Root cause #2 — CONFIRMED via on-device log (2026-08-13):** `utils/debug_file_logger.dart` (external-storage variant, see Frontend architecture above) captured a real 300-500m outdoor walk: only 2 `LocationService._onLocation` entries total, both at app startup 18s apart, identical coordinates, accuracy=100.0 (coarse, not GPS) — these were just the two explicit one-shot `getCurrentLocation()` calls made at startup, not continuous tracking. Zero updates during the actual walk.

Root cause: `AndroidManifest.xml` never declared `android.permission.ACTIVITY_RECOGNITION`, which `flutter_background_geolocation` needs on Android 10+ to run its motion-detection engine (accelerometer + Activity Recognition API) that triggers the stationary→moving transition and starts continuous GPS sampling. Without it, the plugin stays stuck in "stationary" mode forever, only ever answering explicit one-shot location requests — this explains both the static pin colors *and* the 1.2km shop that never disappeared. **Fixed**: added the manifest permission. This is a *runtime* dangerous permission on Android 10+ — the plugin should auto-request it at `.start()` now that it's declared (same pattern as its existing location-permission request), but this needs on-device confirmation: watch for a new "Physical activity" permission prompt on next app launch and grant it. **Not yet retested on-device as of this writing** — next step is another real walk with the new build, then pull the log again and confirm `LocationService._onLocation` entries now appear continuously (not just 2 startup entries).

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
