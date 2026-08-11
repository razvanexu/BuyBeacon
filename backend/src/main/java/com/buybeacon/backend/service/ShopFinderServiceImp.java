package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.dto.ShopResponseDto;
import com.buybeacon.backend.exception.ApiException;
import com.buybeacon.backend.scraper.common.Product;
import com.buybeacon.backend.scraper.orchestration.ScraperOrchestrator;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.stream.Collectors;

/**
 * Dependency injection for WebSearchService and GeocodingService;
 */
@Service
public class ShopFinderServiceImp implements ShopFinderService {
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderServiceImp.class);

    // Only retailer currently backed by a real RetailerScraper implementation (see CarrefourScraper).
    // Extend this list as more retailer-specific scrapers are added.
    private static final List<String> ENRICHMENT_RETAILERS = List.of("Carrefour");

    private final WebSearchService webSearchService;
    private final GooglePlacesClient googlePlacesClient;
    private final ScraperOrchestrator scraperOrchestrator;
    private final ExecutorService scrapingExecutor;

    public ShopFinderServiceImp(WebSearchService webSearchService, GooglePlacesClient googlePlacesClient,
                                 ScraperOrchestrator scraperOrchestrator,
                                 @Qualifier("scrapingExecutor") ExecutorService scrapingExecutor) {
        this.webSearchService = webSearchService;
        this.googlePlacesClient = googlePlacesClient;
        this.scraperOrchestrator = scraperOrchestrator;
        this.scrapingExecutor = scrapingExecutor;
    }

    private static Map<String, List<String>> getShopToProducts(Map<String, List<String>> productToShopNames) {
        return productToShopNames
                .entrySet()
                .stream()
                .flatMap(entry -> entry.getValue()
                        .stream()
                        .map(shopName -> Map.entry(shopName, entry.getKey())))
                .collect(Collectors.groupingBy(
                        Map.Entry::getKey,
                        Collectors.collectingAndThen(Collectors.mapping(Map.Entry::getValue, Collectors.toSet()),
                                ArrayList::new
                        )));
    }

    private String isSuccessfulResponse(JsonNode response, String shopName) {
        String status = response.path("status").asText();
        if (!"OK".equals(status) && !"ZERO_RESULTS".equals(status)) {
            logger.error("Google Places API returned error status: {} for query: {}", status, shopName);
            throw new ApiException("Google Places API error: " + status, HttpStatus.BAD_GATEWAY);
        }
        return status;
    }

    private void createShopResponseDto(String status, JsonNode response, List<ShopResponseDto> allShops,
                                       List<String> associatedProducts) {
        if ("OK".equals(status)) {
            for (JsonNode result : response.path("results")) {
                String name = result.path("name").asText();
                JsonNode location = result.path("geometry").path("location");
                allShops.add(new ShopResponseDto(name,
                        location.path("lat").asDouble(),
                        location.path("lng").asDouble(),
                        associatedProducts));
            }
        }
    }

    @Override
    public List<ShopResponseDto> findShops(List<String> products, Double latitude, Double longitude) {
        if (products == null || products.isEmpty()) {
            logger.warn("findShops called with a null or empty list");
            return Collections.emptyList();
        }

        // Each product's discovery (web search + retailer-scraper enrichment) is independent,
        // so run them concurrently on the bounded scrapingExecutor rather than one after another.
        List<CompletableFuture<Map.Entry<String, List<String>>>> discoveryFutures = products.stream()
                .map(product -> CompletableFuture.supplyAsync(
                        () -> Map.entry(product, findShopNamesForProduct(product)), scrapingExecutor))
                .toList();

        Map<String, List<String>> productToShopNames = discoveryFutures.stream()
                .map(CompletableFuture::join)
                .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));

        Map<String, List<String>> shopNameToProducts = getShopToProducts(productToShopNames);
        logger.info("Found {} unique potential shop names from web search.", shopNameToProducts.size());

        return getGeocodedShops(shopNameToProducts, latitude, longitude);
    }

    /**
     * Finds candidate shop names for a product by combining the generic web-search discovery
     * with a targeted check against known retailer scrapers (e.g. Carrefour). The latter confirms
     * real product availability rather than just guessing a shop name from search results, so it's
     * added as an extra candidate on top of (not instead of) the web-search results.
     */
    private List<String> findShopNamesForProduct(String product) {
        Set<String> shopNames = new LinkedHashSet<>(webSearchService.findShopLocations(product));

        for (String retailerName : ENRICHMENT_RETAILERS) {
            List<Product> retailerMatches = scraperOrchestrator.tryScrapeProducts(product, retailerName);
            if (!retailerMatches.isEmpty()) {
                logger.info("Retailer scraper confirmed '{}' is available at '{}'", product, retailerName);
                shopNames.add(retailerName);
            }
        }
        return new ArrayList<>(shopNames);
    }

    private List<ShopResponseDto> getGeocodedShops(Map<String, List<String>> shopNameToProducts,
                                                    Double latitude, Double longitude) {
        List<CompletableFuture<List<ShopResponseDto>>> geocodingFutures = shopNameToProducts.entrySet().stream()
                .map(entry -> CompletableFuture.supplyAsync(
                        () -> geocodeShop(entry.getKey(), entry.getValue(), latitude, longitude), scrapingExecutor))
                .toList();

        return geocodingFutures.stream()
                .map(CompletableFuture::join)
                .flatMap(List::stream)
                .distinct()
                .toList();
    }

    private List<ShopResponseDto> geocodeShop(String shopName, List<String> associatedProducts,
                                               Double latitude, Double longitude) {
        List<ShopResponseDto> shops = new ArrayList<>();
        try {
            logger.info("Querying Google Places API for shop: '{}'", shopName);
            // With known coordinates, bias results via the API's location/radius params instead
            // of relying on "near me" text, which Google resolves from the *server's* IP address
            // rather than the end user's actual location.
            String query = (latitude != null && longitude != null) ? shopName : shopName + " near me";
            JsonNode response = googlePlacesClient.findPlaces(query, latitude, longitude);

            String status = isSuccessfulResponse(response, shopName);

            createShopResponseDto(status, response, shops, associatedProducts);
        } catch (Exception e) {
            logger.error("Error querying Google Places API for shop: '{}'", shopName, e);
        }
        return shops;
    }
}
