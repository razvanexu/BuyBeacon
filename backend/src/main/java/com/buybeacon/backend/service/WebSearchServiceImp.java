package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Locale;
import java.util.Set;

/**
 * Discovers candidate shops for a product using Google Places Nearby Search, based on
 * the product's crowdsourced category (see ProductCategoryService) rather than matching the
 * product name as free text — Places has no notion of which shops sell a given product, only
 * of place categories/types, so category-based search is what actually finds relevant shops.
 */
@Service
public class WebSearchServiceImp implements WebSearchService {
    private static final Logger logger = LoggerFactory.getLogger(WebSearchServiceImp.class);

    private static final String FALLBACK_PLACES_TYPE = "store";

    // Google has two overlapping, inconsistently-applied Places types for grocery stores --
    // some branches (especially smaller formats like convenience-store-style supermarkets, or
    // discount chains) are tagged with only one of the two. Querying just "supermarket" silently
    // misses real, nearby stores tagged "grocery_or_supermarket" instead.
    private static final Map<String, List<String>> PLACES_TYPE_SYNONYMS = Map.of(
            "supermarket", List.of("supermarket", "grocery_or_supermarket")
    );

    // Confirmed on-device (2026-09-12): a real, nearby Penny discount supermarket -- one whose
    // own Places entry lists "grocery_or_supermarket" in its "types" -- was excluded from Nearby
    // Search results under both "type=supermarket" and "type=grocery_or_supermarket", even when
    // the search origin was placed exactly on top of it (distance 0). A "keyword"-based query
    // (matched against name/types text, not the strict internal "type" filter) does find it, so
    // each of these is queried as an extra fallback and merged in for categories known to hit
    // this gap. "grocery store" is kept alongside "supermarket" (not instead of) since it
    // surfaces a slightly different result set (e.g. "Berezka store & cuisine" wasn't found by
    // either type-based query or the "supermarket" keyword alone).
    private static final Map<String, List<String>> PLACES_KEYWORD_FALLBACKS = Map.of(
            "supermarket", List.of("supermarket", "grocery store")
    );

    // Words that describe a kind of shop rather than identify one (Romanian and English,
    // diacritics already stripped), so they can't make two nearby shops look like one.
    private static final Set<String> GENERIC_NAME_WORDS = Set.of(
            "magazin", "magazinul", "alimentar", "alimentara", "market", "minimarket",
            "supermarket", "hypermarket", "store", "shop", "nonstop", "non", "stop",
            "express", "extra", "city", "bacania", "carmangeria",
            "srl", "sa", "si", "and", "the", "de", "la");
    private static final int MIN_DISTINCTIVE_LENGTH = 4;

    private final GooglePlacesClient googlePlacesClient;
    private final ProductCategoryService productCategoryService;
    private final PhysicalStoreDiscoveryService physicalStoreDiscoveryService;

    @Autowired
    public WebSearchServiceImp(GooglePlacesClient googlePlacesClient,
                                ProductCategoryService productCategoryService,
                                PhysicalStoreDiscoveryService physicalStoreDiscoveryService) {
        this.googlePlacesClient = googlePlacesClient;
        this.productCategoryService = productCategoryService;
        this.physicalStoreDiscoveryService = physicalStoreDiscoveryService;
    }

    @Override
    public List<DiscoveredShop> findShopLocations(String product, Double latitude, Double longitude) {
        if (product == null || product.isBlank()) {
            return Collections.emptyList();
        }

        if (latitude == null || longitude == null) {
            logger.warn("Cannot perform category-based shop discovery for product '{}' without coordinates", product);
            return Collections.emptyList();
        }

        String category = productCategoryService.lookupCategory(product).orElse(FALLBACK_PLACES_TYPE);
        List<String> placesTypes = PLACES_TYPE_SYNONYMS.getOrDefault(category, List.of(category));

        Map<String, DiscoveredShop> shopsByKey = new LinkedHashMap<>();
        for (String type : placesTypes) {
            for (DiscoveredShop shop : searchNearbyByType(product, type, latitude, longitude)) {
                shopsByKey.putIfAbsent(shop.identityKey(), shop);
            }
        }

        for (String keyword : PLACES_KEYWORD_FALLBACKS.getOrDefault(category, List.of())) {
            for (DiscoveredShop shop : searchNearbyByKeyword(product, keyword, latitude, longitude)) {
                shopsByKey.putIfAbsent(shop.identityKey(), shop);
            }
        }

        // OpenStreetMap fills the main coverage gap left by Places: independent
        // neighbourhood shops. The OSM provider only returns customer-facing
        // physical retail features and deliberately excludes offices,
        // warehouses, private locations and online-only entries.
        for (PhysicalStoreCandidate candidate :
                physicalStoreDiscoveryService.findNearby(category, latitude, longitude)) {
            DiscoveredShop osmShop = new DiscoveredShop(
                    candidate.name(), candidate.latitude(), candidate.longitude(), candidate.sourceId());
            if (shopsByKey.values().stream().noneMatch(existing -> samePhysicalStore(existing, osmShop))) {
                shopsByKey.putIfAbsent(osmShop.identityKey(), osmShop);
            }
        }

        logger.info("Found {} potential shops for product {}", shopsByKey.size(), product);
        return new ArrayList<>(shopsByKey.values());
    }

    /**
     * Avoids duplicate pins when the same branch exists in both Places and OSM.
     * Name alone is not an identity (chains reuse it), so proximity is required too.
     * Sources rarely spell a shop identically ("SuperMercato" vs "SuperMercato - Magazin
     * Italian Banu Manta", "Băcănia János Bácsi" vs "Băcănia Janos Bacsi"), so names only
     * need to overlap: one contains the other, or they share a distinctive word. Generic
     * words are ignored, otherwise e.g. "Mic magazin" would swallow every "... Magazin"
     * next door.
     */
    private boolean samePhysicalStore(DiscoveredShop first, DiscoveredShop second) {
        if (!first.hasCoordinates() || !second.hasCoordinates()) {
            return false;
        }
        if (distanceMeters(first.latitude(), first.longitude(), second.latitude(), second.longitude()) > 75) {
            return false;
        }
        return namesOverlap(first.name(), second.name());
    }

    boolean namesOverlap(String firstName, String secondName) {
        List<String> firstWords = distinctiveWords(firstName);
        List<String> secondWords = distinctiveWords(secondName);
        String first = String.join("", firstWords);
        String second = String.join("", secondWords);
        if (first.isEmpty() || second.isEmpty()) {
            return false;
        }
        if (first.equals(second)) {
            return true;
        }
        String shorter = first.length() <= second.length() ? first : second;
        String longer = shorter == first ? second : first;
        if (shorter.length() >= MIN_DISTINCTIVE_LENGTH && longer.contains(shorter)) {
            return true;
        }
        return firstWords.stream()
                .filter(word -> word.length() >= MIN_DISTINCTIVE_LENGTH)
                .anyMatch(secondWords::contains);
    }

    // Lowercased, diacritics stripped, punctuation inside words dropped ("Lu-Jo" ->
    // "lujo", "Shop&Go" -> "shopgo"), generic words removed.
    private List<String> distinctiveWords(String name) {
        if (name == null) {
            return List.of();
        }
        String folded = Normalizer.normalize(name, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT)
                .replaceAll("[-&'.]", "");
        return Arrays.stream(folded.split("[^\\p{L}\\p{N}]+"))
                .filter(word -> !word.isEmpty() && !GENERIC_NAME_WORDS.contains(word))
                .toList();
    }

    private double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
        double earthRadius = 6_371_000;
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private List<DiscoveredShop> searchNearbyByType(String product, String type, double latitude, double longitude) {
        try {
            logger.info("Performing Places nearby search for product '{}' with type: {}", product, type);
            JsonNode response = googlePlacesClient.findNearbyPlaces(type, latitude, longitude);
            String status = response.path("status").asText();

            if (!"OK".equals(status)) {
                logger.warn("Places API returned status '{}' for product '{}' (type: {})", status, product, type);
                return Collections.emptyList();
            }

            List<DiscoveredShop> shops = new ArrayList<>();
            for (JsonNode result : response.path("results")) {
                String name = result.path("name").asText();
                String placeId = result.path("place_id").asText(null);
                JsonNode location = result.path("geometry").path("location");
                shops.add(new DiscoveredShop(name, location.path("lat").asDouble(), location.path("lng").asDouble(), placeId));
            }
            return shops;
        } catch (Exception e) {
            logger.error("Error querying Places API for product '{}' (type: {})", product, type, e);
            return Collections.emptyList();
        }
    }

    private List<DiscoveredShop> searchNearbyByKeyword(String product, String keyword, double latitude, double longitude) {
        try {
            logger.info("Performing Places nearby search for product '{}' with keyword: {}", product, keyword);
            JsonNode response = googlePlacesClient.findNearbyPlacesByKeyword(keyword, latitude, longitude);
            String status = response.path("status").asText();

            if (!"OK".equals(status)) {
                logger.warn("Places API returned status '{}' for product '{}' (keyword: {})", status, product, keyword);
                return Collections.emptyList();
            }

            List<DiscoveredShop> shops = new ArrayList<>();
            for (JsonNode result : response.path("results")) {
                String name = result.path("name").asText();
                String placeId = result.path("place_id").asText(null);
                JsonNode location = result.path("geometry").path("location");
                shops.add(new DiscoveredShop(name, location.path("lat").asDouble(), location.path("lng").asDouble(), placeId));
            }
            return shops;
        } catch (Exception e) {
            logger.error("Error querying Places API for product '{}' (keyword: {})", product, keyword, e);
            return Collections.emptyList();
        }
    }
}
