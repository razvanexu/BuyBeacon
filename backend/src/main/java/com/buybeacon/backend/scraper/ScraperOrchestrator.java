package com.buybeacon.backend.scraper;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.List;
import java.util.Set;

/**
 * Manages and delegates scraping tasks to the appropriate retail scraper
 */
@Service
public class ScraperOrchestrator {
    private final Set<RetailerScraper> retailerScrapers;

    @Autowired
    public ScraperOrchestrator(Set<RetailerScraper> retailerScrapers) {
        this.retailerScrapers = retailerScrapers;
    }

    /**
     * Finds the correct scraper for the given retailer and executes the scrape.
     *
     * @param query The product to search for.
     * @param retailerName The unique identifier for the retailer (e.g., "carrefour").
     * @return A list of found products.
     * @throws IOException if a network error occurs.
     * @throws IllegalArgumentException if no scraper is found for the given identifier.
     */

    public List<Product> scrapeProducts(String query, String retailerName) throws IOException {
        RetailerScraper scraper = retailerScrapers.stream()
                .filter(s -> s.supports(retailerName)) //finds the scraper by name
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("No scraper found for retailer: " + retailerName));

        return scraper.scrapeProducts(query); //returns the query for the found scraper or throws exception.
    }

}
