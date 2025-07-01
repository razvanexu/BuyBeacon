### **Product Requirements Document: Geo-Notification Shopping Assistant (Project Sentinel)**

**1. Introduction**

This document defines the requirements for "Project Sentinel," a mobile application designed to help users find and be reminded of products they need when they are physically near a store that sells them. The user creates a shopping list within the app. A backend service then searches the web to find local retailers for those products. The mobile app uses this location data to create geofences and notifies the user when they enter the proximity of a relevant store.

This initial version (MVP) will focus on proving the core functionality: list creation, web searching, geofencing, and notifications.

**2. Vision & Goals**

*   **Vision:** To create a "smart" shopping list that proactively helps users complete their errands by bridging the gap between their to-do list and their physical location.
*   **User Problem:** Users often have a list of items to buy but may forget them or miss opportunities to purchase them when they are near a relevant store during their daily travels.
*   **Project Goals:**
    *   **User Goal:** Empower users to save time and reduce forgotten errands by providing timely, location-aware reminders.
    *   **Technical Goal:** Build a scalable and functional prototype consisting of a cross-platform mobile frontend and a robust Java-based backend.

**3. User Personas**

*   **The Busy Professional (Alex):** Works a demanding job and runs errands on the way home. Alex needs an efficient way to remember to pick up items (e.g., "printer ink," "a specific brand of coffee") without going out of the way. The value for Alex is convenience and time saved.
*   **The Savvy Shopper (Maria):** Is looking for specific, sometimes hard-to-find items (e.g., "a particular craft supply," "a niche electronic component"). Maria values knowing which stores might carry her items so she can plan her shopping trips effectively.

**4. Features & Requirements (MVP)**

**4.1. Feature: Product List Management (Frontend)**

*   **Description:** The user must be able to maintain a simple list of desired products.
*   **User Stories:**
    *   As a user, I want to add a product to my shopping list by typing its name.
    *   As a user, I want to view all the products currently on my list.
    *   As a user, I want to remove a product from my list.
*   **Requirements:**
    *   The UI will consist of a text input field, an "Add" button, and a simple list view.
    *   Each item in the list will have a "Delete" or "X" button next to it.
    *   The product list must be sent to the backend for processing whenever it is updated.

**4.2. Feature: Location Processing (Backend)**

*   **Description:** The backend service is responsible for finding potential retailers for the products on the user's list.
*   **User Stories:**
    *   As the system, when I receive a list of products, I need to perform a web search for each one to find stores that sell it.
    *   As the system, I need to extract the physical store addresses from the search results.
    *   As the system, I need to convert those addresses into latitude and longitude coordinates.
    *   As the system, I need to send a list of these coordinates back to the mobile app.
*   **Requirements:**
    *   The backend will expose a REST API endpoint (e.g., `POST /api/shops`).
    *   It will use a web scraping library (e.g., JSoup) to parse search engine results.
    *   It will use a geocoding service (e.g., Google Geocoding API) to get coordinates for addresses.

**4.3. Feature: Geofence Notifications (Frontend)**

*   **Description:** The mobile app must monitor the user's location and notify them when they are near a relevant store.
*   **User Stories:**
    *   As a user, I want to be able to set a notification radius (e.g., 500m, 1km, 2km).
    *   As a user, I want to receive a push notification on my phone when I enter the radius of a store that may have an item on my list.
    *   As a user, I must be prompted to grant location permissions for the app to function.
*   **Requirements:**
    *   The app must request `ACCESS_FINE_LOCATION` and `ACCESS_BACKGROUND_LOCATION` permissions.
    *   It will use the device's native geofencing APIs to register geofences for each coordinate received from the backend.
    *   The geofencing must operate even when the app is in the background.
    *   The notification will display a simple message (e.g., "You are near [Store Name], which may have [Product Name].").

**5. Out of Scope for MVP**

To ensure a focused and achievable first version, the following features will **NOT** be included:

*   User accounts and login. The list is stored locally on the device for V1.
*   Real-time inventory or stock checking. The app will only suggest that a store *may* have an item.
*   Price comparisons.
*   E-commerce integration or in-app purchasing.
*   Multiple shopping lists.
*   Sharing lists with other users.

**6. Technical Architecture**

*   **Frontend:** Cross-platform mobile application built with **Flutter (Dart)**.
    *   Plugins: `geolocator`, `geofence_service`, `http`.
*   **Backend:** REST API built with **Java & Spring Boot**.
    *   Dependencies: `spring-boot-starter-web`, `jsoup`.
*   **APIs & Services:**
    *   **Google Geocoding API:** To convert addresses to coordinates. An API key will be required.
    *   **Web Search:** The backend will programmatically query a public search engine.

**7. Success Metrics**

The MVP will be considered a success if:

*   A user can successfully add and remove items from a list in the app.
*   The backend successfully receives the list, scrapes for shops, and returns valid coordinates.
*   The frontend successfully registers a geofence for a returned coordinate.
*   A notification is correctly triggered when the device running the app enters the defined geofence area.
