package com.buybeacon.backend;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.service.WebSearchService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalManagementPort;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "management.server.port=0")
class ActuatorMetricsExposureIntegrationTest {

    private final HttpClient http = HttpClient.newHttpClient();

    @LocalServerPort
    private int serverPort;

    @LocalManagementPort
    private int managementPort;

    @DynamicPropertySource
    static void mainManagementProperties(DynamicPropertyRegistry registry) throws IOException {
        Properties main = new Properties();
        try (InputStream in = Files.newInputStream(Path.of("src/main/resources/application.properties"))) {
            main.load(in);
        }
        main.stringPropertyNames().stream()
                .filter(key -> key.startsWith("management."))
                .forEach(key -> registry.add(key, () -> main.getProperty(key)));
    }

    @MockitoBean
    private WebSearchService webSearchService;

    @MockitoBean
    private GooglePlacesClient googlePlacesClient;

    @Test
    void actuatorIsNotServedOnTheApplicationPort() throws Exception {
        assertThat(get(serverPort, "/actuator/metrics").statusCode()).isEqualTo(404);
        assertThat(get(serverPort, "/actuator/health").statusCode()).isEqualTo(404);
    }

    @Test
    void metricsAndHealthAreServedOnTheManagementPort() throws Exception {
        assertThat(get(managementPort, "/actuator/health").statusCode()).isEqualTo(200);
        assertThat(get(managementPort, "/actuator/metrics").statusCode()).isEqualTo(200);
    }

    @Test
    void otherActuatorEndpointsStayUnexposed() throws Exception {
        assertThat(get(managementPort, "/actuator/env").statusCode()).isEqualTo(404);
        assertThat(get(managementPort, "/actuator/beans").statusCode()).isEqualTo(404);
    }

    @Test
    void requestLatencyPublishesPercentiles() throws Exception {
        assertThat(get(serverPort, "/api/products/categories").statusCode()).isEqualTo(200);

        HttpResponse<String> p95 = get(managementPort,
                "/actuator/metrics/http.server.requests.percentile?tag=uri:/api/products/categories&tag=phi:0.95");

        assertThat(p95.statusCode()).isEqualTo(200);
        assertThat(p95.body()).contains("\"name\":\"http.server.requests.percentile\"");
    }

    private HttpResponse<String> get(int port, String path) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).GET().build();
        return http.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
