package com.buybeacon.backend.service;

import com.buybeacon.backend.client.OpenStreetMapOverpassClient;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Discovers neighbourhood shops from OpenStreetMap. Queries only retail tags
 * representing customer-facing locations, then applies a defensive filter for
 * closed, private, warehouse, office and online-only entries.
 */
@Service
public class OpenStreetMapPhysicalStoreDiscoveryService implements PhysicalStoreDiscoveryService {
    private static final Logger logger = LoggerFactory.getLogger(OpenStreetMapPhysicalStoreDiscoveryService.class);

    private static final Map<String, Set<String>> CATEGORY_TO_SHOP_TYPES = Map.of(
            "supermarket", Set.of("supermarket", "convenience", "grocery", "deli", "greengrocer"),
            "hardware_store", Set.of("hardware", "doityourself", "trade", "building_materials"),
            "pharmacy", Set.of("chemist"),
            "electronics_store", Set.of("electronics", "electrical", "computer", "mobile_phone"),
            "clothing_store", Set.of("clothes", "shoes", "fashion", "second_hand"),
            "pet_store", Set.of("pet"),
            "book_store", Set.of("books", "stationery"),
            "store", Set.of("general", "department_store", "variety_store")
    );

    private static final Set<String> REJECTED_SHOP_TYPES = Set.of(
            "vacant", "closed", "disused", "abandoned", "warehouse", "online", "pickup"
    );
    private static final Set<String> REJECTED_ACCESS = Set.of("private", "no");

    private final OpenStreetMapOverpassClient overpassClient;
    private final boolean enabled;
    private final int radiusMeters;
    private final int maxResults;
    private final Duration cacheTtl;
    private final Map<CacheKey, CacheEntry> cache = new ConcurrentHashMap<>();

    public OpenStreetMapPhysicalStoreDiscoveryService(
            OpenStreetMapOverpassClient overpassClient,
            @Value("${openstreetmap.overpass.enabled:true}") boolean enabled,
            @Value("${openstreetmap.overpass.radius-meters:2000}") int radiusMeters,
            @Value("${openstreetmap.overpass.max-results:20}") int maxResults,
            @Value("${openstreetmap.overpass.cache-seconds:120}") long cacheSeconds) {
        this.overpassClient = overpassClient;
        this.enabled = enabled;
        this.radiusMeters = Math.max(100, radiusMeters);
        this.maxResults = Math.max(1, maxResults);
        this.cacheTtl = Duration.ofSeconds(Math.max(0, cacheSeconds));
    }

    @Override
    public List<PhysicalStoreCandidate> findNearby(String categoryCode, double latitude, double longitude) {
        if (!enabled || categoryCode == null || !validCoordinates(latitude, longitude)) {
            return List.of();
        }

        Set<String> shopTypes = CATEGORY_TO_SHOP_TYPES.get(categoryCode);
        if (shopTypes == null || shopTypes.isEmpty()) {
            logger.warn("No OpenStreetMap shop mapping for category '{}'", categoryCode);
            return List.of();
        }

        Instant now = Instant.now();
        cache.entrySet().removeIf(entry -> !entry.getValue().createdAt().plus(cacheTtl).isAfter(now));

        CacheKey cacheKey = new CacheKey(categoryCode, roundedCoordinate(latitude), roundedCoordinate(longitude));
        CacheEntry cached = cache.get(cacheKey);
        if (cached != null) {
            return cached.candidates();
        }

        try {
            JsonNode response = overpassClient.execute(buildQuery(categoryCode, shopTypes, latitude, longitude));
            List<PhysicalStoreCandidate> candidates = parseCandidates(response, shopTypes, latitude, longitude);
            cache.put(cacheKey, new CacheEntry(Instant.now(), candidates));
            return candidates;
        } catch (Exception e) {
            // OSM is an optional enrichment source. Its availability must not
            // make the primary shop-search request fail.
            logger.warn("OpenStreetMap shop discovery failed for category '{}': {}", categoryCode, e.getMessage());
            return List.of();
        }
    }

    String buildQuery(String categoryCode, Set<String> shopTypes, double latitude, double longitude) {
        String typeRegex = String.join("|", shopTypes.stream().sorted().toList());
        String around = "(around:" + radiusMeters + "," + latitude + "," + longitude + ")";
        StringBuilder query = new StringBuilder("[out:json][timeout:10];(")
                .append("nwr").append(around)
                .append("[\"shop\"~\"^(").append(typeRegex).append(")$\"];");
        if ("pharmacy".equals(categoryCode)) {
            query.append("nwr").append(around).append("[\"amenity\"=\"pharmacy\"];");
        }
        return query.append(");out center tags;").toString();
    }

    private List<PhysicalStoreCandidate> parseCandidates(
            JsonNode response,
            Set<String> allowedShopTypes,
            double originLatitude,
            double originLongitude) {
        if (response == null || !response.path("elements").isArray()) {
            return List.of();
        }

        Map<String, PhysicalStoreCandidate> unique = new LinkedHashMap<>();
        for (JsonNode element : response.path("elements")) {
            JsonNode tags = element.path("tags");
            if (!isCustomerFacingPhysicalStore(tags, allowedShopTypes)) {
                continue;
            }

            Double latitude = coordinate(element, "lat");
            Double longitude = coordinate(element, "lon");
            if (latitude == null || longitude == null || !validCoordinates(latitude, longitude)) {
                continue;
            }

            String elementType = element.path("type").asText();
            String elementId = element.path("id").asText();
            if (elementType.isBlank() || elementId.isBlank()) {
                continue;
            }

            String storeType = storeType(tags);
            String sourceId = "osm:" + elementType + ":" + elementId;
            String name = firstNonBlank(
                    tags.path("name").asText(),
                    tags.path("brand").asText(),
                    tags.path("operator").asText(),
                    fallbackName(storeType));
            unique.putIfAbsent(sourceId, new PhysicalStoreCandidate(
                    sourceId, name, latitude, longitude, storeType, "openstreetmap"));
        }

        return unique.values().stream()
                .sorted(Comparator.comparingDouble(candidate -> distanceMeters(
                        originLatitude, originLongitude, candidate.latitude(), candidate.longitude())))
                .limit(maxResults)
                .toList();
    }

    private boolean isCustomerFacingPhysicalStore(JsonNode tags, Set<String> allowedShopTypes) {
        if (!tags.isObject()) {
            return false;
        }
        String shopType = tags.path("shop").asText().toLowerCase(Locale.ROOT);
        boolean mappedShop = allowedShopTypes.contains(shopType);
        boolean mappedPharmacy = "pharmacy".equals(tags.path("amenity").asText());
        if (!mappedShop && !mappedPharmacy) {
            return false;
        }
        if (REJECTED_SHOP_TYPES.contains(shopType)
                || REJECTED_ACCESS.contains(tags.path("access").asText().toLowerCase(Locale.ROOT))) {
            return false;
        }
        return !hasTruthyTag(tags, "disused")
                && !hasTruthyTag(tags, "abandoned")
                && !hasTruthyTag(tags, "demolished")
                && !hasTruthyTag(tags, "construction")
                && !tags.has("disused:shop")
                && !tags.has("abandoned:shop")
                && !tags.has("office")
                && !tags.has("warehouse")
                && !"yes".equalsIgnoreCase(tags.path("online_only").asText());
    }

    private boolean hasTruthyTag(JsonNode tags, String key) {
        String value = tags.path(key).asText();
        return "yes".equalsIgnoreCase(value) || "true".equalsIgnoreCase(value);
    }

    private String storeType(JsonNode tags) {
        String shop = tags.path("shop").asText();
        return shop.isBlank() ? tags.path("amenity").asText() : shop;
    }

    private Double coordinate(JsonNode element, String field) {
        JsonNode direct = element.get(field);
        if (direct != null && direct.isNumber()) {
            return direct.asDouble();
        }
        JsonNode centered = element.path("center").get(field);
        return centered != null && centered.isNumber() ? centered.asDouble() : null;
    }

    private String fallbackName(String storeType) {
        return switch (storeType) {
            case "supermarket", "convenience", "grocery", "deli", "greengrocer" -> "Magazin alimentar";
            case "hardware", "doityourself", "trade", "building_materials" -> "Magazin de bricolaj";
            case "chemist", "pharmacy" -> "Farmacie";
            case "electronics", "electrical", "computer", "mobile_phone" -> "Magazin de electronice";
            case "clothes", "shoes", "fashion", "second_hand" -> "Magazin de îmbrăcăminte";
            case "pet" -> "Magazin pentru animale";
            case "books", "stationery" -> "Librărie";
            default -> "Magazin local";
        };
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return "Magazin local";
    }

    private boolean validCoordinates(double latitude, double longitude) {
        return Double.isFinite(latitude) && Double.isFinite(longitude)
                && latitude >= -90 && latitude <= 90
                && longitude >= -180 && longitude <= 180;
    }

    private double roundedCoordinate(double coordinate) {
        return Math.rint(coordinate * 1000) / 1000;
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

    private record CacheKey(String category, double latitude, double longitude) {
    }

    private record CacheEntry(Instant createdAt, List<PhysicalStoreCandidate> candidates) {
    }
}
