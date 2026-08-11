package com.buybeacon.backend.scraper.orchestration;

import com.buybeacon.backend.scraper.common.Product;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.Collections;
import java.util.List;
import java.util.Set;

/**
 * Manages and delegates scraping tasks to the appropriate retail scraper
 */
@Service
public class ScraperOrchestrator {
    private static final Logger logger = LoggerFactory.getLogger(ScraperOrchestrator.class);

    private final Set<RetailerScraper> retailerScrapers;

    @Autowired
    public ScraperOrchestrator(Set<RetailerScraper> retailerScrapers) {
        this.retailerScrapers = retailerScrapers;
    }

    /**
     * Best-effort variant of {@link #scrapeProducts(String, String)} for callers that want to treat
     * this retailer scraper as an optional enrichment source rather than a hard dependency.
     * Any failure (network error, unsupported retailer) is logged and results in an empty list
     * instead of propagating.
     *
     * @param query The product to search for.
     * @param retailerName The unique identifier for the retailer (e.g., "carrefour").
     * @return The scraped products, or an empty list if the scrape failed or the retailer isn't supported.
     */
    public List<Product> tryScrapeProducts(String query, String retailerName) {
        try {
            return scrapeProducts(query, retailerName);
        } catch (IOException | IllegalArgumentException e) {
            logger.warn("Retailer scrape for '{}' on '{}' failed, skipping: {}", query, retailerName, e.getMessage());
            return Collections.emptyList();
        }
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
