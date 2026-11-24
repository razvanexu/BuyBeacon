package com.buybeacon.backend.client;

import com.fasterxml.jackson.databind.JsonNode;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.restclient.RestTemplateBuilder;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

@Service
public class GooglePlacesClient {
    private static final Logger logger = LoggerFactory.getLogger(GooglePlacesClient.class);

    private static final String NEARBY_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json";
    static final String REQUESTS_METRIC = "places.api.requests";
    private final RestTemplate restTemplate;
    private final String apiKey;
    private final MeterRegistry meterRegistry;

    @Autowired
    public GooglePlacesClient(RestTemplateBuilder restTemplateBuilder,
                              @Value("${google.maps.api.key}") String apiKey,
                              MeterRegistry meterRegistry) {
        // Without explicit timeouts, a single stalled Places API call can hang forever and,
        // combined with the bounded scrapingExecutor pool, starve every other concurrent
        // discovery call waiting for a free thread.
        // Explicitly forced onto the Jackson 2 converter: Spring Boot 4.1's default RestTemplate
        // JSON converter is Jackson 3 (tools.jackson.*), which can't deserialize into the Jackson 2
        // com.fasterxml.jackson.databind.JsonNode this client (and its callers) return.
        this.restTemplate = restTemplateBuilder
                .connectTimeout(Duration.ofSeconds(10))
                .readTimeout(Duration.ofSeconds(10))
                .messageConverters(new MappingJackson2HttpMessageConverter())
                .build();
        this.apiKey = apiKey;
        this.meterRegistry = meterRegistry;
    }

    private JsonNode timedRequest(String query, URI uri) {
        long start = System.nanoTime();
        String outcome = "error";
        try {
            JsonNode response = restTemplate.getForObject(uri, JsonNode.class);
            outcome = "success";
            return response;
        } finally {
            Timer.builder(REQUESTS_METRIC)
                    .tag("query", query)
                    .tag("outcome", outcome)
                    .register(meterRegistry)
                    .record(System.nanoTime() - start, TimeUnit.NANOSECONDS);
        }
    }

    // RestTemplate treats a String URL as a template and encodes it again, and
    // UriComponentsBuilder.toUriString() already encodes once -- so any space
    // reached Google as literal "%20" (e.g. keyword "grocery store" matched
    // "20 St. Market" in Philadelphia). Passing a URI is sent as-is.
    private static URI toUri(UriComponentsBuilder builder) {
        return builder.encode().build().toUri();
    }

    /**
     * Searches for places of a given category (Places "type") near a location. It doesn't
     * match free text against place names/types; it directly asks for places of that type,
     * which is what category-based shop discovery needs.
     * <p>
     * Uses rankby=distance instead of a radius: Nearby Search defaults to ranking by
     * "prominence" (rating/popularity), which can rank a big-box store several km away above a
     * small local shop right across the street. rankby=distance forces strict distance ordering
     * so genuinely close matches surface reliably (Google requires omitting "radius" when
     * "rankby=distance" is used).
     */
    public JsonNode findNearbyPlaces(String type, double latitude, double longitude) {
        UriComponentsBuilder builder = UriComponentsBuilder.fromUriString(NEARBY_SEARCH_URL)
                .queryParam("type", type)
                .queryParam("location", latitude + "," + longitude)
                .queryParam("rankby", "distance")
                .queryParam("key", this.apiKey);

        logger.info("Accessing maps nearby-search api with type {}", type);
        return timedRequest("type", toUri(builder));
    }

    /**
     * Like findNearbyPlaces, but matches on free-text "keyword" instead of the strict "type"
     * filter. Some real, nearby places (confirmed on-device: a Penny discount supermarket
     * literally co-located with the search origin) are excluded by "type" matching entirely --
     * Google appears to filter Nearby Search's "type" against a place's single internal primary
     * type rather than its full legacy "types" list, so a place can list e.g.
     * "grocery_or_supermarket" in "types" yet still never match "type=grocery_or_supermarket".
     * "keyword" matches against the place's name/types text instead and isn't subject to that,
     * so it's used as a fallback query merged alongside the type-based ones (see
     * WebSearchServiceImp) rather than a replacement -- combining "type" and "keyword" in one
     * request applies them as AND, which would still exclude the same places.
     */
    public JsonNode findNearbyPlacesByKeyword(String keyword, double latitude, double longitude) {
        UriComponentsBuilder builder = UriComponentsBuilder.fromUriString(NEARBY_SEARCH_URL)
                .queryParam("keyword", keyword)
                .queryParam("location", latitude + "," + longitude)
                .queryParam("rankby", "distance")
                .queryParam("key", this.apiKey);

        logger.info("Accessing maps nearby-search api with keyword {}", keyword);
        return timedRequest("keyword", toUri(builder));
    }
}
