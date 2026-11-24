package com.buybeacon.backend.client;

import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.boot.restclient.RestTemplateBuilder;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.HttpServerErrorException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.allOf;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

/**
 * Goes through the client's real RestTemplate, since that's where a String URL
 * used to get encoded a second time ("grocery store" -> "grocery%2520store").
 */
class GooglePlacesClientTest {

    private static final String EMPTY_OK = "{\"status\":\"OK\",\"results\":[]}";

    private MockRestServiceServer server;

    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();

    private final GooglePlacesClient client = new GooglePlacesClient(
            new RestTemplateBuilder().additionalCustomizers(
                    restTemplate -> server = MockRestServiceServer.bindTo(restTemplate).build()),
            "test-key",
            meterRegistry);

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
    void findNearbyPlaces_recordsSuccessfulTypeRequest() {
        server.expect(requestTo(containsString("type=supermarket")))
                .andRespond(withSuccess(EMPTY_OK, MediaType.APPLICATION_JSON));

        client.findNearbyPlaces("supermarket", 44.456, 26.073);

        assertThat(requestCount("type", "success")).isEqualTo(1);
        assertThat(meterRegistry.find(GooglePlacesClient.REQUESTS_METRIC).timers()).hasSize(1);
    }

    @Test
    void findNearbyPlacesByKeyword_recordsSuccessfulKeywordRequest() {
        server.expect(requestTo(containsString("keyword=supermarket")))
                .andRespond(withSuccess(EMPTY_OK, MediaType.APPLICATION_JSON));

        client.findNearbyPlacesByKeyword("supermarket", 44.456, 26.073);

        assertThat(requestCount("keyword", "success")).isEqualTo(1);
        assertThat(meterRegistry.find(GooglePlacesClient.REQUESTS_METRIC).timers()).hasSize(1);
    }

    @Test
    void findNearbyPlaces_recordsFailedRequestAndRethrows() {
        server.expect(requestTo(containsString("type=pharmacy")))
                .andRespond(withServerError());

        assertThatThrownBy(() -> client.findNearbyPlaces("pharmacy", 44.456, 26.073))
                .isInstanceOf(HttpServerErrorException.class);

        assertThat(requestCount("type", "error")).isEqualTo(1);
        assertThat(meterRegistry.find(GooglePlacesClient.REQUESTS_METRIC).timers()).hasSize(1);
    }

    @Test
    void repeatedRequests_accumulateOnTheSameTimer() {
        server.expect(requestTo(containsString("type=supermarket")))
                .andRespond(withSuccess(EMPTY_OK, MediaType.APPLICATION_JSON));
        server.expect(requestTo(containsString("type=pharmacy")))
                .andRespond(withSuccess(EMPTY_OK, MediaType.APPLICATION_JSON));

        client.findNearbyPlaces("supermarket", 44.456, 26.073);
        client.findNearbyPlaces("pharmacy", 44.456, 26.073);

        assertThat(requestCount("type", "success")).isEqualTo(2);
    }

    private long requestCount(String query, String outcome) {
        Timer timer = meterRegistry.find(GooglePlacesClient.REQUESTS_METRIC)
                .tag("query", query)
                .tag("outcome", outcome)
                .timer();
        return timer == null ? 0 : timer.count();
    }
}
