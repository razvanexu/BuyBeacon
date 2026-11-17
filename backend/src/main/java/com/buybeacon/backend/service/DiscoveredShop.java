package com.buybeacon.backend.service;

/**
 * A shop candidate discovered during shop-finding (Google Places Nearby Search or OpenStreetMap),
 * carrying the coordinates it was discovered at. ShopFinderServiceImp drops any candidate without
 * coordinates, since nothing downstream can place it on the map or geofence it.
 *
 * placeId is the source's own unique identifier for the physical location (a Google place_id, or
 * an "osm:"-prefixed OpenStreetMap id). It's the real identity of a shop candidate for
 * deduplication purposes -- unlike name, which many
 * chains (Mega Image, Carrefour Express, Froo, Shop & Go, ...) reuse identically across dozens of
 * separate physical branches in the same city, so deduplicating by name alone silently collapses
 * distinct nearby branches into one, keeping only whichever happened to be inserted first.
 */
public record DiscoveredShop(String name, Double latitude, Double longitude, String placeId,
                             String source, String matchConfidence) {

    public DiscoveredShop(String name, Double latitude, Double longitude, String placeId) {
        this(name, latitude, longitude, placeId,
                placeId != null && placeId.startsWith("osm:") ? "openstreetmap" : "google_places",
                "CATEGORY_MATCH");
    }

    public boolean hasCoordinates() {
        return latitude != null && longitude != null;
    }

    /**
     * A stable key identifying the real-world candidate this represents, for deduplication.
     * Uses placeId when known (the true identity of a physical location); falls back to name
     * only for candidates that don't carry one.
     */
    public String identityKey() {
        if (placeId == null) {
            return "name:" + name;
        }
        // OSM candidates already carry a namespaced identifier such as
        // osm:node:123. Places IDs are kept under their original namespace.
        return placeId.startsWith("osm:") ? placeId : "place:" + placeId;
    }
}
