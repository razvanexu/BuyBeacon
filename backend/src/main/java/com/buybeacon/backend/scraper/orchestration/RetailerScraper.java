package com.buybeacon.backend.scraper.orchestration;

import com.buybeacon.backend.scraper.common.Product;

import java.io.IOException;
import java.util.List;

public interface RetailerScraper {

    /**
     * Scrapes a retailer's website for products matching a given query.
     *
     * @param query The product search term.
     * @return A list of Product objects found.
     * @throws IOException if a network error occurs during scraping.
     */
    List<Product> scrapeProducts(String query) throws IOException;

    /**
     * Checks if this scraper implementation supports a given retailer identifier.
     * This allows the system to select the correct scraper for a specific retailer.
     *
     * @param retailerName A unique string identifying the retailer (e.g., "carrefour").
     * @return true if this scraper can handle the specified retailer, false otherwise.
     */
    boolean supports(String retailerName);
}
