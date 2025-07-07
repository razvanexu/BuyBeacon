package com.buybeacon.backend.service;

import java.util.List;
public interface WebSearchService {
    /**
     * Searches for potential physical store locations for a given product query.
     *
     * @param product The name of the product to search for (e.g., "printer ink").
     * @return A List of strings, where each string is a potential store name or address found in the search results.
     */
    List<String> findShopLocations (String product);
}
