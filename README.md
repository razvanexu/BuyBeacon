# BuyBeacon

A location-aware shopping list. Add product names on your phone, and BuyBeacon
notifies you — even in the background — when you walk or drive near a shop
that is likely to carry them. A map screen shows nearby matching shops as
live, distance-colored pins (green = closest, yellow = within 500 m,
red = within 1 km).

This monorepo has two halves:

| Folder      | What                                  | Stack                          |
|-------------|---------------------------------------|--------------------------------|
| `frontend/` | Mobile app ([README](frontend/README.md)) | Flutter / Dart, Provider, Tracelet |
| `backend/`  | Shop-discovery REST API               | Java 21, Spring Boot 4, PostgreSQL |

## How it works

1. The user adds a product. The first time a product name is seen, the app asks
   for its shop category (supermarket, pharmacy, hardware store, …). Picks are
   stored in a small shared product → category dictionary on the backend.
2. The app sends the product list plus its current location to
   `POST /api/shops/find`.
3. For each product, the backend combines several sources:
   - **Google Places Nearby Search** by category type (plus a keyword-based
     fallback for supermarkets, where the type filter misses real shops).
   - **OpenStreetMap (Overpass)** for small neighbourhood shops Places often
     misses. It's optional: if Overpass is unavailable, the search continues
     with Places alone.
   - **Retailer catalog check** (currently Carrefour only, scraped via Selenium)
     to confirm a product is actually listed.
4. Results are deduplicated per physical branch (Google `place_id`, or name +
   ≤75 m across sources) and returned with each shop's `source`
   (`google_places`, `openstreetmap`, `retailer_catalog`) and `matchConfidence`
   (`CATEGORY_MATCH` or `RETAILER_CATALOG`).
5. The app registers proximity checks around those shops, re-fetches after
   moving ≥300 m, and sends a notification for the closest newly entered shop.

## API

| Method | Path                          | Purpose                                   |
|--------|-------------------------------|-------------------------------------------|
| POST   | `/api/shops/find`             | Find nearby shops for a list of products  |
| GET    | `/api/products/category`      | Look up a product's known category        |
| POST   | `/api/products/category`      | Save the user's category pick             |
| GET    | `/api/products/categories`    | List pickable categories                  |

Interactive docs are at `/swagger-ui.html` when running locally (disabled
under the `prod` profile).

## Running the backend

Create `backend/.env`. It isn't committed:

```
GOOGLE_MAPS_API_KEY=...
DB_PASSWORD=...
# optional
DB_USERNAME=buybeacon
DEBUG_LOG_TOKEN=...          # enables the temporary /api/debug/log sink
OVERPASS_URL=...             # default: https://overpass-api.de/api/interpreter
OVERPASS_ENABLED=true
```

**Docker (backend + PostgreSQL + Selenium):**

```
cd backend
docker compose up -d --build
```

The API is exposed on host port `8090` and runs with `SPRING_PROFILES_ACTIVE=prod`.
After a base-image or dependency change, rebuild with
`docker compose build --no-cache backend`.

**Locally (no Docker for the app itself):** start `postgres` (and optionally
`selenium`) from the compose file, then:

```
cd backend
./mvnw spring-boot:run
./mvnw test
```

## Running the app

See [`frontend/README.md`](frontend/README.md). In short:
`flutter pub get`, then `flutter run` (LAN backend), or build a release APK
pointing at the public backend with
`--dart-define=API_BASE_URL=https://api.cloudavenue.ro`.

## Deployment

The backend runs on a home server and is exposed through a Cloudflare Tunnel
at `https://api.cloudavenue.ro`. To update it, pull the latest code on the
server, then run `docker compose up -d --build backend` from `backend/`.

## Known limitations

- The public Overpass server is rate-limited and often returns
  `502 at capacity`. OpenStreetMap results then silently drop to zero.
  Self-hosting Overpass is the long-term fix.
- Results are only as good as Google's and OSM's categorization: a business
  mis-tagged as a supermarket on Google will show up as one.
- `DebugLogController` / `DebugFileLogger` are temporary diagnostics tooling
  and will be removed.

Map data from OpenStreetMap is © OpenStreetMap contributors, available under
the [ODbL](https://www.openstreetmap.org/copyright).
