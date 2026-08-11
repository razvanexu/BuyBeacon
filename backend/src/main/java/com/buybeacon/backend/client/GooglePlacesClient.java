package com.buybeacon.backend.client;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class GooglePlacesClient {
    private static  final Logger logger = LoggerFactory.getLogger(GooglePlacesClient.class);

    private static final String PLACES_API_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json";
    private final RestTemplate restTemplate;
    private final String apiKey;

    @Autowired
    public GooglePlacesClient(RestTemplateBuilder restTemplateBuilder, @Value("${google.maps.api.key}") String apiKey) {
        this.restTemplate = restTemplateBuilder.build();
        this.apiKey = apiKey;
    }

    // Biasing radius (meters) applied around the user's coordinates when searching for shops.
    private static final int SEARCH_RADIUS_METERS = 15_000;

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
}
