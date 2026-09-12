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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
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
        // Take only the top (closest/most relevant, given the location bias) result. Shop names
        // that reach this point without coordinates are generic brand names (e.g. "Carrefour"
        // from retailer enrichment), and Text Search matches every branch of that brand in the
        // search radius — without this, a single dense chain can return dozens of branches.
        if ("OK".equals(status) && response.path("results").size() > 0) {
            JsonNode result = response.path("results").get(0);
            String name = result.path("name").asText();
            JsonNode location = result.path("geometry").path("location");
            allShops.add(new ShopResponseDto(name,
                    location.path("lat").asDouble(),
                    location.path("lng").asDouble(),
                    associatedProducts));
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
        List<CompletableFuture<Map.Entry<String, List<DiscoveredShop>>>> discoveryFutures = products.stream()
                .map(product -> CompletableFuture.supplyAsync(
                        () -> Map.entry(product, findShopsForProduct(product, latitude, longitude)), scrapingExecutor))
                .toList();

        Map<String, List<DiscoveredShop>> productToShops = discoveryFutures.stream()
                .map(CompletableFuture::join)
                .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue));

        // Group discoveries by shop identity (Places place_id when known, across all products) --
        // NOT by name, since chains like Mega Image/Carrefour Express/Froo reuse the exact same
        // display name across dozens of distinct physical branches in the same city; keying by
        // name alone would silently collapse separate nearby branches into a single pin, keeping
        // only whichever one happened to be inserted first (see CLAUDE.md, 2026-09-12).
        Map<String, List<String>> shopKeyToProducts = new LinkedHashMap<>();
        Map<String, DiscoveredShop> shopByKey = new LinkedHashMap<>();
        for (Map.Entry<String, List<DiscoveredShop>> entry : productToShops.entrySet()) {
            String product = entry.getKey();
            for (DiscoveredShop shop : entry.getValue()) {
                String key = shop.identityKey();
                shopKeyToProducts.computeIfAbsent(key, k -> new ArrayList<>()).add(product);
                shopByKey.putIfAbsent(key, shop);
            }
        }
        logger.info("Found {} unique potential shops from web search.", shopKeyToProducts.size());

        List<ShopResponseDto> resolvedShops = resolveShops(shopKeyToProducts, shopByKey, latitude, longitude);
        logger.info("Returning {} resolved shops out of {} candidates: {}",
                resolvedShops.size(), shopKeyToProducts.size(),
                resolvedShops.stream().map(ShopResponseDto::storeName).toList());
        return resolvedShops;
    }

    /**
     * Finds candidate shops for a product by combining Places-based discovery (already carrying
     * coordinates) with a targeted check against known retailer scrapers (e.g. Carrefour). The
     * latter confirms real product availability rather than just guessing a shop name from search
     * results, so it's added as an extra candidate on top of (not instead of) the Places results —
     * but without coordinates, since the scraper only confirms a name, not a location.
     */
    private List<DiscoveredShop> findShopsForProduct(String product, Double latitude, Double longitude) {
        Map<String, DiscoveredShop> shops = new LinkedHashMap<>();
        for (DiscoveredShop shop : webSearchService.findShopLocations(product, latitude, longitude)) {
            shops.put(shop.identityKey(), shop);
        }

        for (String retailerName : ENRICHMENT_RETAILERS) {
            List<Product> retailerMatches = scraperOrchestrator.tryScrapeProducts(product, retailerName);
            if (!retailerMatches.isEmpty()) {
                logger.info("Retailer scraper confirmed '{}' is available at '{}'", product, retailerName);
                DiscoveredShop enrichmentCandidate = DiscoveredShop.withoutCoordinates(retailerName);
                shops.putIfAbsent(enrichmentCandidate.identityKey(), enrichmentCandidate);
            }
        }
        return new ArrayList<>(shops.values());
    }

    private List<ShopResponseDto> resolveShops(Map<String, List<String>> shopKeyToProducts,
                                                Map<String, DiscoveredShop> shopByKey,
                                                Double latitude, Double longitude) {
        List<CompletableFuture<List<ShopResponseDto>>> resolutionFutures = shopKeyToProducts.entrySet().stream()
                .map(entry -> {
                    DiscoveredShop shop = shopByKey.get(entry.getKey());
                    return CompletableFuture.supplyAsync(
                            () -> resolveShop(shop, shop.name(), entry.getValue(), latitude, longitude),
                            scrapingExecutor);
                })
                .toList();

        return resolutionFutures.stream()
                .map(CompletableFuture::join)
                .flatMap(List::stream)
                .distinct()
                .toList();
    }

    /**
     * Resolves a single shop candidate to its final ShopResponseDto(s). If the candidate already
     * has coordinates (from Places Nearby Search), uses them directly — no need to re-search Places
     * by name, which is both redundant and can miss small/local chains that the original,
     * type+location-filtered Nearby Search found without issue. Otherwise (e.g. retailer-enrichment
     * candidates, which only confirm a name), falls back to geocoding by name via Text Search.
     */
    private List<ShopResponseDto> resolveShop(DiscoveredShop shop, String shopName, List<String> associatedProducts,
                                               Double latitude, Double longitude) {
        if (shop != null && shop.hasCoordinates()) {
            logger.info("Using discovered coordinates for shop '{}' (skipping re-geocode)", shopName);
            return List.of(new ShopResponseDto(shopName, shop.latitude(), shop.longitude(), associatedProducts));
        }
        return geocodeShop(shopName, associatedProducts, latitude, longitude);
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
            logger.info("Geocoding shop '{}' resolved status '{}' -> {} location(s)", shopName, status, shops.size());
        } catch (Exception e) {
            logger.error("Error querying Google Places API for shop: '{}'", shopName, e);
        }
        return shops;
    }
}
