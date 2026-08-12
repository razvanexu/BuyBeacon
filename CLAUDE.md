# BuyBeacon — Project Overview

Buy-reminder mobile app. Full architecture, current state, and known issues, as understood as of **2026-08-12**. See also `GEMINI.md` (older session notes from a different assistant, still accurate for history) and `prd.md` (product requirements).

## What it does

BuyBeacon is a location-aware shopping list. The user adds product names to a list on their phone. The backend finds nearby stores that likely carry each product, geocodes them, and sends coordinates back to the app. The app registers geofences around those coordinates and — even in the background — pushes a notification when the user walks/drives near a relevant store.

Two repos, one Git root (`C:\Projects\BuyBeacon`):
- `frontend/` — Flutter (Dart) mobile app
- `backend/` — Java 21 / Spring Boot REST API

## Backend (`backend/`)

Spring Boot app, Maven (`pom.xml`), single controller-facing endpoint plus a debug endpoint.

**Request flow for `POST /api/shops/find`:**
1. `ShopFinderController` (`controller/ShopFinderController.java`) receives `ProductSearchRequestDto` (`products: List<String>`, optional `latitude`/`longitude`) and delegates to `ShopFinderService`.
2. `ShopFinderServiceImp` (`service/ShopFinderServiceImp.java`) — the core orchestration:
   - For each product (concurrently, via a bounded `scrapingExecutor`), calls `findShopNamesForProduct`:
     - `WebSearchServiceImp` does a **generic web search** ("`<product> store near me`" on `google.com/search`, via Selenium + JSoup parsing) to guess candidate shop names.
     - Separately, checks a hardcoded list `ENRICHMENT_RETAILERS = ["Carrefour"]` against `ScraperOrchestrator`, which dispatches to retailer-specific scrapers. **Carrefour is the only retailer with a real scraper implemented** (`CarrefourScraper`, scrapes `carrefour.ro/catalogsearch`).
   - Merges all candidate shop names, groups them by shop → associated products.
   - Geocodes each shop name via `GooglePlacesClient` (Google Places Find-Place-style text query, biased by lat/lng if provided) → `ShopResponseDto(name, lat, lng, associatedProducts)`.
3. Returns the deduplicated list of `ShopResponseDto` to the frontend.

**Key backend files:**
- `controller/ShopFinderController.java` — main endpoint
- `controller/ScraperController.java` — debug endpoint `GET /api/scrape/products?query=&retailerName=`, calls `ScraperOrchestrator` directly
- `service/ShopFinderServiceImp.java` — core orchestration logic
- `service/WebSearchServiceImp.java` — Google-search scraping (**currently broken**, see Known Issues)
- `service/MockWebSearchServiceImp.java` — `@Profile("test")` stub, returns 3 hardcoded shop names
- `client/GooglePlacesClient.java` — geocoding via Google Places API (actively used)
- `scraper/orchestration/ScraperOrchestrator.java` — dispatches to the right `RetailerScraper` by name
- `scraper/retailers/CarrefourScraper.java` — only concrete retailer scraper; scrapes `carrefour.ro`
- `scraper/common/SeleniumHtmlFetcher.java` (`@Primary`, `@Profile("!test")`) — headless Chrome via remote Selenium (`selenium.remote.url` property), used for both Google search and Carrefour scraping
- `scraper/common/JSoupHtmlFetcher.java` — plain HTTP fetch, non-primary alternative to Selenium
- `scraper/common/JSoupHtmlParser.java` — generic CSS-selector-based HTML → data extraction, includes basic shop-name validation heuristics (filters out URLs, `.ro`/`.com` strings, overly long text)

**Unused / dead code worth knowing about:**
- `service/GeocodingService.java` (interface) + `service/NominatimGeocodingServiceImp.java` (OpenStreetMap Nominatim implementation) + `service/MockGeocodingServiceImp.java` — a full alternate geocoding path exists but **is not wired into `ShopFinderServiceImp`**, which uses `GooglePlacesClient` directly instead. Looks like an earlier design that was superseded but not deleted.

**Deployment note:** backend + a Selenium container run on the user's own machine at home, exposed via a **Cloudflare Tunnel**. The tunnel only affects *inbound* traffic reaching the backend from the internet — outbound requests (backend/Selenium → Google) go out over the home ISP connection, not through Cloudflare.

## Frontend (`frontend/`)

Flutter app, Provider state management, refactored to a layered/SOLID architecture (repository → orchestrator → provider → UI).

**Architecture:**
- `services/database_service.dart` — local SQLite persistence of the product list
- `services/api_service.dart` — singleton HTTP client, `POST /api/shops/find` to the Spring Boot backend (`API_BASE_URL`, default `http://192.168.0.180:8080`, overridable via `--dart-define`)
- `repositories/product_repository.dart` — single point combining local DB (products) + remote API (shop lookup); no business logic
- `providers/product_provider.dart` — `ChangeNotifier` holding the product list; add/delete/load, delegates persistence to the repository; exposes an `onProductsChanged` callback rather than owning geofence/network logic itself
- `orchestrators/shopping_orchestrator.dart` — the "brain": listens to product-list changes, calls the repository to fetch shop locations, updates geofences, handles exponential-backoff retry on backend connection errors, emits a state stream (`isLoading`, `hasConnectionError`, etc.)
- `services/location_service.dart` — live user location only (via `flutter_background_geolocation`)
- `services/geofence_service.dart` — registers/clears geofences from coordinates, exposes a stream of raw enter/exit events (no decision logic)
- `services/notification_decision_service.dart` — debouncing + "notify only for the closest store" decision logic, kept separate from `GeofenceService` per SRP
- `services/notification_service.dart` / `notification_channel_service.dart` — push notification display + Android channel setup
- `screens/home_screen.dart` — product list UI, loading/error states via `StreamBuilder` on the orchestrator's state stream
- `screens/map_screen.dart` — `StatefulWidget` showing a Google Map (`google_maps_flutter`) with the user's location and discovered shop markers (green pins)

**Testing:** integration test (`integration_test/app_test.dart`, split into "backend ON" happy-path and "backend OFF" error-handling groups), widget tests (`test/screens`), unit tests (`test/providers`, `test/services`). Backend has unit tests (Mockito) for `ShopFinderService`, `CarrefourScraper`, `JSoupHtmlParser`, plus `MockMvc` controller tests.

## Known Issues

### Google-search scraping is blocked (active bug, root cause of "always shows Carrefour")

**Symptom:** searching for any product only ever returns a single nearby "Carrefour Express" marker (green), regardless of what was searched.

**Root cause, confirmed 2026-08-12:**
`WebSearchServiceImp` scrapes `google.com/search?q=<product>+store+near+me` and parses results with CSS selectors `div.MjjYud` / `span.VuuXrf`. Tested manually (both from an external sandbox IP and from the user's own home IP, through the same path Selenium would use): Google returns a **~92KB anti-bot "enable JS" gate page** instead of real results, with title `Google Search` and a body redirecting to `/httpservice/retry/enablejs?...`. Zero matches for either CSS selector. This is not just stale selectors — Google is actively blocking/challenging the request, and it reproduces from a residential IP too, so it's not purely a datacenter-IP reputation issue.

Because `ShopFinderServiceImp.ENRICHMENT_RETAILERS` only lists `"Carrefour"` (the only retailer with a real scraper), when the generic web search returns empty (exception caught, logged, empty list returned), **Carrefour ends up as the only shop candidate for every product**, which is why the app always shows just one Carrefour Express pin.

**Agreed direction (discussed with user, not yet implemented — waiting for go-ahead):**
- Replace `WebSearchServiceImp`'s Google-scraping approach with **Google Places API Text Search**, reusing the existing `GooglePlacesClient` (already used for geocoding in `ShopFinderServiceImp.geocodeShop`). Query like `"<product> magazin"` biased by lat/lng, same pattern as the existing geocode call.
- This could merge the "find shop name" and "geocode shop" steps into a single Places call instead of two separate ones.
- Leave `CarrefourScraper`, `ScraperOrchestrator`, `ShopResponseDto`, and the `/api/shops/find` contract unchanged — only the internal shop-discovery source changes.
- Open questions, not yet answered by user:
  1. Does the Google Cloud API key already have Places **Text Search** enabled/billed (not just Nearby Search / Find Place)?
  2. Fully remove Selenium + `WebSearchServiceImp` + the Selenium container, or leave them in place unused as a possible fallback?
- **Do not implement this without explicit confirmation from the user first** — they've asked to always lay out the plan and wait for a go-ahead before writing backend code on this project.

## Useful pointers

- Diagrams: `Diagrams/` (`backend_flowchart.mmd`, `sequence_notification.mmd`, `v1_architecture.mmd`, etc.)
- Older rolling session notes (Gemini-authored, still relevant history): `GEMINI.md`
- Product requirements: `prd.md`
