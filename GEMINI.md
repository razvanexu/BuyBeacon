## Operating Instructions
**IMPORTANT:** Do not ever write files to the user's computer unless specifically instructed to do so. Provide the code or content to the user instead.

-----

## Project: BuyBeacon
**Overview:** A smart shopping list application. The Flutter frontend allows users to create a list of products. The Java/Spring Boot backend scrapes the web to find stores selling those products, geocodes their locations, and returns them to the app. The app then creates geofences around the stores and notifies the user via push notification when they are nearby.

**Last Session Summary (2025-07-23):**
- Analyzed the project's overall architecture and purpose by examining `frontend/pubspec.yaml`, `backend/pom.xml`, `frontend/integration_test/app_test.dart`, and `Diagrams/sequence_notification.mmd`.
- Determined the core functionality: a location-aware shopping list that notifies users when they are near a store with an item on their list.

**Backend Overview:**
The backend is a modular, multi-layered Spring Boot application that handles the core logic of finding and geocoding stores. It uses a two-step process: first, it uses a Selenium-based web scraper to perform a broad Google search for potential store names related to a product. Second, it uses the Google Places API to get accurate geographic coordinates (latitude/longitude) for those store names. The backend also includes a separate, extensible framework for scraping specific, individual retailer websites (e.g., Carrefour).

**Key Backend Files:**
- **Main Controller:** `backend/src/main/java/com/buybeacon/backend/controller/ShopFinderController.java`
- **Core Logic:** `backend/src/main/java/com/buybeacon/backend/service/ShopFinderServiceImp.java`
- **Web Search/Scraping:** `backend/src/main/java/com/buybeacon/backend/service/WebSearchServiceImp.java`
- **Geocoding Client:** `backend/src/main/java/com/buybeacon/backend/client/GooglePlacesClient.java`
- **Retailer Scraping Orchestrator:** `backend/src/main/java/com/buybeacon/backend/scraper/orchestration/ScraperOrchestrator.java`
- **Example Retailer Scraper:** `backend/src/main/java/com/buybeacon/backend/scraper/retailers/CarrefourScraper.java`

**Frontend Overview:**
The frontend is a feature-complete Flutter application built with the Provider state management pattern. It handles the entire user-facing experience, including creating and managing a shopping list, which is persisted locally using an SQLite database. The app's core feature is a reactive geofence loop: any change to the shopping list automatically triggers a call to the backend to get updated store locations. It then uses the `flutter_background_geolocation` package to monitor these locations, even when the app is in the background or terminated. Upon entering a geofence, it displays a rich, dynamic push notification to the user.

**Key Frontend Files:**
- **Main UI:** `frontend/lib/screens/home_screen.dart`
- **State Management & Core Logic:** `frontend/lib/providers/product_provider.dart`
- **API Communication:** `frontend/lib/services/api_service.dart`
- **Background Location:** `frontend/lib/services/location_service.dart`
- **Local Database:** `frontend/lib/services/database_service.dart`
- **Push Notifications:** `frontend/lib/services/notification_service.dart`

## Testing Overview

The project has a comprehensive and mature testing strategy covering both the frontend and backend, ensuring high confidence in the application's correctness and stability.

**Backend Testing Strategy:**
The backend relies on a strong foundation of unit and slice-integration tests, following modern Spring Boot practices.
- **Unit Tests:** Core business logic (`ShopFinderService`), data transformation (`CarrefourScraper`), and fragile parsing logic (`JSoupHtmlParser`) are thoroughly unit-tested in isolation using Mockito. This ensures the most complex parts of the system are verified without external dependencies.
- **Controller Tests:** The API layer (`ShopFinderController`) is tested using `MockMvc`, which simulates HTTP requests and asserts responses without needing a full running server. This validates request handling, serialization, and error responses.
- **Overall:** The backend tests are fast, reliable, and effectively cover the application's logic layer by layer.

**Frontend Testing Strategy:**
The frontend follows the Flutter testing pyramid with excellent coverage across all levels.
- **Integration Test (`integration_test`):** A full end-to-end test validates the primary user journey of adding, duplicating, and deleting a product, ensuring all parts of the app (UI, state, database, services) work together.
- **Widget Tests (`test/screens`):** The UI components are tested in isolation by mocking the `ProductProvider`. This verifies that the UI correctly renders all possible states (loading, empty, data) and that user interactions (button taps) trigger the appropriate business logic.
- **Unit Tests (`test/providers`, `test/services`):** The application's core logic (`ProductProvider`) and individual services (`LocationService`) are unit-tested by mocking their dependencies. These tests verify complex logic flows, edge cases, and interactions with native platform channels, demonstrating a high degree of test quality.

## Session Summary (2025-08-04 - Present):**

*   **SOLID Architecture Refactoring:**
    *   **Goal:** Refactored the entire frontend application to align with SOLID principles, improving testability, maintainability, and scalability.
    *   **`ProductRepository`:** Created a new repository class (`lib/repositories/product_repository.dart`) whose single responsibility is to handle all data operations (local database and remote API calls). This abstracts the data sources from the rest of the app.
    *   **`GeofenceService` & `LocationService`:** Separated the responsibilities of location tracking and geofence management. `LocationService` now only manages the user's live location. The new `GeofenceService` manages adding/clearing geofences and handling transition events.
    *   **`ShoppingOrchestrator`:** Created a new orchestrator class (`lib/orchestrators/shopping_orchestrator.dart`) to act as the "brain" of the application. It listens for changes from the `ProductProvider` and coordinates the `ProductRepository` and `GeofenceService` to fetch shop data and update geofences. It also contains the exponential backoff logic for handling network errors.
    *   **`ProductProvider`:** Simplified the `ProductProvider` to be a focused state manager for the product list only. It no longer contains data fetching or geofence logic, instead delegating those tasks to the orchestrator via a callback.
    *   **`NotificationChannelService`:** Created a dedicated service (`lib/services/notification_channel_service.dart`) to define and provide all Android Notification Channels, ensuring a single source of truth for notification configuration and preventing dependency coupling between other services.
    *   **UI Layer (`HomeScreen`, `MapScreen`):** The UI widgets were refactored to be "dumber." They now get their state from multiple providers (`ProductProvider`, `LocationService`, `GeofenceService`, and `ShoppingOrchestrator`) to build the UI, but contain no business logic themselves.
    *   **Error Handling:** Implemented robust error handling for backend connection failures, including a `SnackBar` notification for the user and an exponential backoff retry mechanism.
    *   **Bug Fixes:** Corrected several bugs related to state management, asynchronous operations in tests, and notification display logic.
    *   **Outcome:** The application now has a clean, decoupled architecture with a unidirectional data flow, making it more robust and easier to maintain and test.

## Session Summary (2025-08-17):

*   **`MapScreen` Crash Fix & Refactor:**
    *   Diagnosed and fixed a `_TypeError` (Null check operator used on a null value) that occurred when building the `MapScreen`. The root cause was an unsafe access of `userLocation.coords` when the location object from the provider was not fully populated.
    *   Corrected the logic by implementing a more robust null check (`userLocation?.coords == null`) at the top of the widget's build method.
    *   As part of the fix, converted `MapScreen` from a `StatelessWidget` to a `StatefulWidget` to correctly manage the `GoogleMapController`'s lifecycle, ensuring the map camera now follows the user's location.

*   **`HomeScreen` UI Fix:**
    *   Resolved a bug where the `LinearProgressIndicator` was not appearing during data loading operations.
    *   Replaced a `Consumer` widget with a `StreamBuilder` to correctly listen to the `ShoppingOrchestrator`'s `onStateChanged` stream, ensuring the UI now accurately reflects the `isLoading` state.

*   **Code Quality Improvements:**
    *   Confirmed that two previously identified issues were resolved: the confusing debug notification was removed from `GeofenceService`, and hardcoded notification channel details were eliminated from `NotificationService`.

## Session Summary (2025-08-18):

*   **Notification Logic Refactoring (SOLID):**
    *   **Goal:** Refactored the notification logic to only alert the user for the single closest store when multiple geofences are entered at once.
    *   **Initial Implementation:** A debouncing mechanism was added to `GeofenceService`.
    *   **SOLID Refinement:** Recognizing that the initial implementation violated the Single Responsibility Principle, the architecture was further refined.
        *   A new `NotificationDecisionService` was created to encapsulate all business logic related to notifications (debouncing, proximity calculation, decision making).
        *   The `GeofenceService` was simplified back to its core responsibility: managing geofences and exposing a stream of raw geofence events.
        *   `main.dart` was updated to instantiate and initialize the new service, completing the decoupled architecture.

*   **End-to-End Testing:**
    *   Created a comprehensive E2E test suite in `integration_test/app_test.dart`.
    *   The suite is divided into two groups, clarifying the required backend state for each:
        1.  **Happy Path (Backend ON):** A test that covers the full user journey: adding a product, verifying duplicate prevention, simulating a geofence event using the plugin's `test` API, and verifying navigation after a simulated notification tap.
        2.  **Error Handling (Backend OFF):** A test that verifies the connection error `SnackBar` is displayed correctly when the app cannot reach the backend.
