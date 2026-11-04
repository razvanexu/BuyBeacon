package com.buybeacon.backend.client;

import org.junit.jupiter.api.Test;
import org.springframework.boot.restclient.RestTemplateBuilder;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;

import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

/**
 * Goes through the client's real RestTemplate, since that's where a String URL
 * used to get encoded a second time ("grocery store" -> "grocery%2520store").
 */
class GooglePlacesClientTest {

    private static final String EMPTY_OK = "{\"status\":\"OK\",\"results\":[]}";

    private MockRestServiceServer server;

    private final GooglePlacesClient client = new GooglePlacesClient(
            new RestTemplateBuilder().additionalCustomizers(
                    restTemplate -> server = MockRestServiceServer.bindTo(restTemplate).build()),
            "test-key");

    @Test
    void findNearbyPlacesByKeyword_encodesSpacesExactlyOnce() {
        server.expect(requestTo(allOf(
                        containsString("keyword=grocery%20store"),
                        not(containsString("%25")))))
                .andRespond(withSuccess(EMPTY_OK, MediaType.APPLICATION_JSON));

        client.findNearbyPlacesByKeyword("grocery store", 44.456, 26.073);

        server.verify();
    }

    @Test
    void findPlaces_encodesShopNameExactlyOnce() {
        server.expect(requestTo(allOf(
                        containsString("query=Carrefour%20Express"),
                        not(containsString("%25")))))
                .andRespond(withSuccess(EMPTY_OK, MediaType.APPLICATION_JSON));

        client.findPlaces("Carrefour Express", 44.456, 26.073);

        server.verify();
    }
}
