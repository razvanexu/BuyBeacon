package com.buybeacon.backend.service;

/**
 * A shop-name candidate discovered during shop-finding, optionally already carrying real
 * coordinates (e.g. from Places Nearby Search results, which already include location data).
 * When latitude/longitude are present, ShopFinderServiceImp skips re-geocoding entirely --
 * re-searching a generic name via Text Search is both redundant (Nearby Search already gave us
 * a precise, type+location-filtered match) and unreliable (Text Search can miss small/local
 * chains that Nearby Search found just fine). Candidates without coordinates (e.g. retailer
 * enrichment matches, which only confirm a name, not a location) still go through geocoding.
 */
public record DiscoveredShop(String name, Double latitude, Double longitude) {

    public static DiscoveredShop withoutCoordinates(String name) {
        return new DiscoveredShop(name, null, null);
    }

    public boolean hasCoordinates() {
        return latitude != null && longitude != null;
    }
}
