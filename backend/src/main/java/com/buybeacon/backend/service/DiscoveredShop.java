package com.buybeacon.backend.service;

/**
 * A shop-name candidate discovered during shop-finding, optionally already carrying real
 * coordinates (e.g. from Places Nearby Search results, which already include location data).
 * When latitude/longitude are present, ShopFinderServiceImp skips re-geocoding entirely --
 * re-searching a generic name via Text Search is both redundant (Nearby Search already gave us
 * a precise, type+location-filtered match) and unreliable (Text Search can miss small/local
 * chains that Nearby Search found just fine). Candidates without coordinates (e.g. retailer
 * enrichment matches, which only confirm a name, not a location) still go through geocoding.
 *
 * placeId is Google's own unique identifier for the physical location (present on every Places
 * Nearby Search result, null for retailer-enrichment candidates that only confirm a name). It's
 * the real identity of a shop candidate for deduplication purposes -- unlike name, which many
 * chains (Mega Image, Carrefour Express, Froo, Shop & Go, ...) reuse identically across dozens of
 * separate physical branches in the same city, so deduplicating by name alone silently collapses
 * distinct nearby branches into one, keeping only whichever happened to be inserted first.
 */
public record DiscoveredShop(String name, Double latitude, Double longitude, String placeId) {

    public static DiscoveredShop withoutCoordinates(String name) {
        return new DiscoveredShop(name, null, null, null);
    }

    public boolean hasCoordinates() {
        return latitude != null && longitude != null;
    }

    /**
     * A stable key identifying the real-world candidate this represents, for deduplication.
     * Uses placeId when known (the true identity of a physical location); falls back to name
     * only for candidates that don't carry one (e.g. retailer-enrichment matches).
     */
    public String identityKey() {
        return placeId != null ? "place:" + placeId : "name:" + name;
    }
}
