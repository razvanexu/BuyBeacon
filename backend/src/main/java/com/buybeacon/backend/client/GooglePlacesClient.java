package com.buybeacon.backend.client;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.restclient.RestTemplateBuilder;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.time.Duration;

@Service
public class GooglePlacesClient {
    private static final Logger logger = LoggerFactory.getLogger(GooglePlacesClient.class);

    private static final String PLACES_API_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json";
    private static final String NEARBY_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json";
    // Biasing radius (meters) applied around the user's coordinates when searching for shops.
    private static final int SEARCH_RADIUS_METERS = 15_000;
    private final RestTemplate restTemplate;
    private final String apiKey;

    @Autowired
    public GooglePlacesClient(RestTemplateBuilder restTemplateBuilder, @Value("${google.maps.api.key}") String apiKey) {
        // Without explicit timeouts, a single stalled Places API call can hang forever and,
        // combined with the bounded scrapingExecutor pool, starve every other concurrent
        // geocoding/discovery call waiting for a free thread.
        // Explicitly forced onto the Jackson 2 converter: Spring Boot 4.1's default RestTemplate
        // JSON converter is Jackson 3 (tools.jackson.*), which can't deserialize into the Jackson 2
        // com.fasterxml.jackson.databind.JsonNode this client (and its callers) return.
        this.restTemplate = restTemplateBuilder
                .connectTimeout(Duration.ofSeconds(10))
                .readTimeout(Duration.ofSeconds(10))
                .messageConverters(new MappingJackson2HttpMessageConverter())
                .build();
        this.apiKey = apiKey;
    }

    public JsonNode findPlaces(String query, Double latitude, Double longitude) {
        UriComponentsBuilder builder = UriComponentsBuilder.fromUriString(PLACES_API_URL)
                .queryParam("query", query)
                .queryParam("key", this.apiKey);

        if (latitude != null && longitude != null) {
            builder.queryParam("location", latitude + "," + longitude)
                    .queryParam("radius", SEARCH_RADIUS_METERS);
        }

        String url = builder.toUriString();
        logger.info("Accessing maps api with query {}", query);
        return restTemplate.getForObject(url, JsonNode.class);
    }

    /**
     * Searches for places of a given category (Places "type") near a location. Unlike
     * findPlaces (Text Search), this doesn't match free text against place names/types —
     * it directly asks for places of that type, so it's used for category-based shop
     * discovery rather than geocoding a known shop name.
     * <p>
     * Uses rankby=distance instead of a radius: Nearby Search defaults to ranking by
     * "prominence" (rating/popularity), which can rank a big-box store several km away above a
     * small local shop right across the street. rankby=distance forces strict distance ordering
     * so genuinely close matches surface reliably (Google requires omitting "radius" when
     * "rankby=distance" is used).
     */
    public JsonNode findNearbyPlaces(String type, double latitude, double longitude) {
        String url = UriComponentsBuilder.fromUriString(NEARBY_SEARCH_URL)
                .queryParam("type", type)
                .queryParam("location", latitude + "," + longitude)
                .queryParam("rankby", "distance")
                .queryParam("key", this.apiKey)
                .toUriString();

        logger.info("Accessing maps nearby-search api with type {}", type);
        return restTemplate.getForObject(url, JsonNode.class);
    }
}
