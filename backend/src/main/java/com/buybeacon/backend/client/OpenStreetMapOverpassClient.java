package com.buybeacon.backend.client;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.restclient.RestTemplateBuilder;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.time.Duration;

/** HTTP boundary around the OpenStreetMap Overpass API. */
@Service
public class OpenStreetMapOverpassClient {
    private final RestTemplate restTemplate;
    private final String endpoint;

    public OpenStreetMapOverpassClient(
            RestTemplateBuilder restTemplateBuilder,
            @Value("${openstreetmap.overpass.url:https://overpass-api.de/api/interpreter}") String endpoint) {
        this.restTemplate = restTemplateBuilder
                .connectTimeout(Duration.ofSeconds(5))
                .readTimeout(Duration.ofSeconds(12))
                .defaultHeader("User-Agent", "BuyBeacon/1.0")
                .messageConverters(new MappingJackson2HttpMessageConverter())
                .build();
        this.endpoint = endpoint;
    }

    public JsonNode execute(String overpassQuery) {
        String url = UriComponentsBuilder.fromUriString(endpoint)
                .queryParam("data", overpassQuery)
                .build()
                .encode()
                .toUriString();
        return restTemplate.getForObject(url, JsonNode.class);
    }
}
