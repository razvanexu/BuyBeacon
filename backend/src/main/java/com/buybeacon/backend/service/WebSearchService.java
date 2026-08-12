package com.buybeacon.backend.service;

import java.util.List;

public interface WebSearchService {
    /**
     * Searches for potential physical store locations for a given product query,
     * optionally biased toward a given location.
     *
     * @param product The name of the product to search for (e.g., "printer ink").
     * @param latitude Optional latitude to bias results toward, may be null.
     * @param longitude Optional longitude to bias results toward, may be null.
     * @return A List of discovered shops, each carrying real coordinates when the
     *         underlying source already provides them (e.g. Places Nearby Search).
     */
    List<DiscoveredShop> findShopLocations(String product, Double latitude, Double longitude);
}
