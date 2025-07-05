### **Product Requirements Document: BuyBeacon Shopping Assistant**

**1. Introduction**

This document defines the requirements for "BuyBeacon," a smart mobile shopping assistant. The application is designed to serve two primary user needs: providing passive, location-aware reminders for non-urgent items, and offering active, optimized route planning for necessary shopping trips.

**2. Core Product Vision**

*   **Vision:** To create an intelligent shopping assistant that understands the user's intent, saves them time and money, and proactively helps them complete their errands with maximum convenience and efficiency.
*   **User Problem:** Users juggle different types of shopping needs—passive reminders for future purchases and active planning for immediate ones. They lack a single tool that can cater to both, often missing opportunities for convenient pickups or failing to plan efficient, cost-effective shopping trips.

**3. Core Application Modes (The "Action Fork")**

BuyBeacon will be built around two fundamental modes of operation:

*   **1. Ambient Reminder Mode (Passive):** For non-urgent items. The user adds items to a "Reminder List," and the app runs in the background, notifying them only when their daily travels take them near a store that likely sells a needed item. This is the core of the MVP.
*   **2. Active Mission Mode (Active):** For necessary shopping lists. The user builds a specific list for an upcoming trip and asks the app to "Plan My Trip." The app responds by calculating an optimized multi-stop route, suggesting the best stores, and potentially factoring in price and item availability. This is a V2+ feature.

**4. Phase 1: MVP Requirements**

The MVP is focused exclusively on delivering a robust **Ambient Reminder Mode**.

**4.1. Feature: Reminder List Management**
*   **Description:** The user can maintain a simple list of non-urgent products.
*   **User Stories:**
    *   As a user, I want to add a product to my Reminder List by typing its name.
    *   As a user, I want to view all products on my list.
    *   As a user, I want to remove a product from my list.
*   **Requirements:**
    *   The UI will feature a simple text input, an "Add" button, and a list view.
    *   Each list item will have a "Delete" button.
    *   The list is sent to the backend for processing upon updates.

**4.2. Feature: Store Location Processing (Basic)**
*   **Description:** The backend finds potential retailers for products on the user's list.
*   **User Stories:**
    *   As the system, I perform a web search for each product to find stores that sell it.
    *   As the system, I extract physical store addresses from search results.
    *   As the system, I convert addresses into latitude/longitude coordinates.
    *   As the system, I send these coordinates back to the mobile app.
*   **Requirements:**
    *   Backend exposes a REST endpoint (e.g., `POST /api/reminders`).
    *   Uses a web scraping library (JSoup) to parse search results.
    *   Uses a geocoding service (Google Geocoding API).

**4.3. Feature: Geofence Notifications**
*   **Description:** The app monitors the user's location and notifies them when they are near a relevant store.
*   **User Stories:**
    *   As a user, I want to set a notification radius (e.g., 500m, 1km).
    *   As a user, I want to receive a push notification when I enter the radius of a store that may have an item on my list.
    *   As a user, I must be prompted to grant location permissions.
*   **Requirements:**
    *   Request `ACCESS_FINE_LOCATION` and `ACCESS_BACKGROUND_LOCATION` permissions.
    *   Use native geofencing APIs to register geofences from backend coordinates.
    *   Geofencing must operate when the app is in the background.

**5. Out of Scope for MVP**

To ensure a focused and achievable first version, the following are explicitly **NOT** included:
*   **Active Mission Mode** and all related features (route planning, store optimization).
*   **Intelligent Suggestion Engine** (price comparisons, alternative product suggestions).
*   User accounts and login. The list is stored locally on the device.
*   Real-time inventory or stock checking.
*   Multiple, separate shopping lists.

**6. Phase 2: V2+ Future Development Roadmap**

This section outlines features to be developed after the MVP is successfully launched and validated.

**6.1. Feature: Active Mission Mode**
*   **Description:** Allows users to plan an efficient, multi-stop shopping trip.
*   **User Stories:**
    *   As a user, I want to create a dedicated "Shopping Trip" list.
    *   As a user, I want to press a "Plan My Trip" button to receive an optimized route.
    *   As a user, I want to see the suggested route on a map within the app.
    *   As a user, I want to be able to start turn-by-turn navigation for the route in my preferred maps app (e.g., Google Maps).

**6.2. Feature: Intelligent Suggestion Engine (AI-Powered)**
*   **Description:** A backend service that provides smart recommendations to save users time and money.
*   **User Stories:**
    *   As a user in Mission Mode, I want the app to suggest alternative stores on my route where items might be cheaper.
    *   As a user in Reminder Mode, I want a notification to include if an item is on sale or cheaper at another nearby store.
    *   As a user, I want the app to learn my preferred stores and prioritize them when making suggestions.

**7. Technical Architecture & Evolution**

*   **MVP Frontend:** Flutter (Dart) with `geolocator`, `geofence_service`, `http`.
*   **MVP Backend:** Java & Spring Boot with `spring-boot-starter-web`, `jsoup`.
*   **V2+ Backend Evolution:**
    *   The monolith will be enhanced with new service components for routing and suggestions.
    *   Introduce an **AI/ML component** for intelligent store matching, price analysis, and route optimization. This may involve Python-based microservices (e.g., using FastAPI, scikit-learn, TensorFlow) integrated via API calls.
*   **APIs & Services:**
    *   **Google Geocoding API:** (MVP)
    *   **Google Maps SDK:** (V2+ for displaying routes)
    *   **AI Models:** (V2+ for advanced logic)

**8. Success Metrics**

*   **MVP Success:**
    *   A user can successfully manage a Reminder List.
    *   The backend successfully returns valid coordinates for items.
    *   A geofence notification is correctly triggered when the user enters the defined area.
*   **V2+ Success:**
    *   Users can successfully generate an optimized shopping route.
    *   The Intelligent Suggestion Engine leads to a measurable metric, such as "X% of users chose a cheaper suggested store."
    *   High user retention and engagement with both core application modes.
