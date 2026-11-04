package com.buybeacon.backend.client;

import org.junit.jupiter.api.Test;
import org.springframework.boot.restclient.RestTemplateBuilder;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

class OpenStreetMapOverpassClientTest {

    private final OpenStreetMapOverpassClient client =
            new OpenStreetMapOverpassClient(new RestTemplateBuilder(), "http://overpass/api/interpreter");

    @Test
    void buildUri_encodesQueryExactlyOnce() {
        String query = "[out:json][timeout:10];(nwr(around:2000,44.456,26.073)[\"shop\"~\"^(convenience|supermarket)$\"];);out center tags;";

        URI uri = client.buildUri(query);

        assertFalse(uri.getRawQuery().contains("%25"), "query was double-encoded: " + uri.getRawQuery());
        String data = uri.getRawQuery().substring("data=".length());
        assertEquals(query, URLDecoder.decode(data, StandardCharsets.UTF_8));
    }
}
