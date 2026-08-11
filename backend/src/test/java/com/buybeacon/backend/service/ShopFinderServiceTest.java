package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.dto.ShopResponseDto;
import com.buybeacon.backend.scraper.common.Product;
import com.buybeacon.backend.scraper.orchestration.ScraperOrchestrator;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.IOException;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ShopFinderServiceTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private WebSearchService webSearchService;
    @Mock
    private GooglePlacesClient googlePlacesClient;
    @Mock
    private ScraperOrchestrator scraperOrchestrator;

    private ExecutorService executorService;
    private ShopFinderServiceImp shopFinderService;

    @BeforeEach
    void setUp() {
        // Single-threaded executor keeps test execution deterministic while still exercising
        // the same CompletableFuture-based code path used in production.
        executorService = Executors.newSingleThreadExecutor();
        shopFinderService = new ShopFinderServiceImp(webSearchService, googlePlacesClient, scraperOrchestrator,
                executorService);
        lenient().when(scraperOrchestrator.tryScrapeProducts(anyString(), anyString()))
                .thenReturn(Collections.emptyList());
    }

    @AfterEach
    void tearDown() {
        executorService.shutdown();
    }

    @Test
    void findShops_shouldAggregateAndReturnUniqueShops() throws IOException {
        //ARRANGE
        when(webSearchService.findShopLocations("milk")).thenReturn(List.of("Carrefour", "Mega Image"));
        when(webSearchService.findShopLocations("bread")).thenReturn(List.of("Carrefour", "Lidl"));

        JsonNode carrefourResponse = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":[{\"name\":\"Carrefour Vitan\",\"geometry\":{\"location\":{\"lat\":44" +
                        ".4,\"lng\":26.1}}}]}"
        );

        JsonNode megaImageResponse = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":[{\"name\":\"Mega Image Unirii\"," +
                        "\"geometry\":{\"location\":{\"lat\":44.42,\"lng\":26.11}}}]}"
        );

        JsonNode lidlResponse = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":[{\"name\":\"Lidl Discount\",\"geometry\":{\"location\":{\"lat\":44" +
                        ".45,\"lng\":26.05}}}]}"
        );

        when(googlePlacesClient.findPlaces("Carrefour near me", null, null)).thenReturn(carrefourResponse);
        when(googlePlacesClient.findPlaces("Mega Image near me", null, null)).thenReturn(megaImageResponse);
        when(googlePlacesClient.findPlaces("Lidl near me", null, null)).thenReturn(lidlResponse);

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk", "bread"), null, null);

        //ASSERT
        assertNotNull(result);
        assertEquals(3, result.size(), "Should find 3 unique shops");

        ShopResponseDto carrefour = result
                .stream()
                .filter(s -> s.storeName()
                        .equals("Carrefour Vitan"))
                .findFirst()
                .orElse(null);

        assertNotNull(carrefour, "Carrefour should be in the list");
        assertEquals(2, carrefour.products().size(), "Carrefour should have 2 products");
        assertTrue(carrefour.products().containsAll(List.of("milk", "bread")), "Carrefour should have milk and bread");
        assertEquals(44.4, carrefour.latitude());
        assertEquals(26.1, carrefour.longitude());

        ShopResponseDto megaImage = result
                .stream()
                .filter(s -> s.storeName()
                        .equals("Mega Image Unirii"))
                .findFirst()
                .orElse(null);

        assertNotNull(megaImage, "Mega Image should be in the list");
        assertEquals(1, megaImage.products().size(), "MegaImage should have 1 product");
        assertEquals("milk", megaImage.products().get(0), "MegaImage should have milk");
        assertEquals(44.42, megaImage.latitude());
        assertEquals(26.11, megaImage.longitude());

        ShopResponseDto lidl = result
                .stream()
                .filter(s -> s.storeName()
                        .equals("Lidl Discount"))
                .findFirst()
                .orElse(null);

        assertNotNull(lidl, "Lidl should be in the list");
        assertEquals(1, lidl.products().size(), "Lidl should have 1 product");
        assertEquals("bread", lidl.products().get(0), "Lidl should have bread");
        assertEquals(44.45, lidl.latitude());
        assertEquals(26.05, lidl.longitude());
    }

    @Test
    void findShops_ShouldHandleGoogleApiErrorsGracefully() throws IOException {
        //ARRANGE
        when(webSearchService.findShopLocations(anyString())).thenReturn(List.of("Failing Shop"));
        JsonNode errorResponse = objectMapper.readTree("{\"status\":\"REQUEST_DENIED\"}");
        when(googlePlacesClient.findPlaces(anyString(), any(), any())).thenReturn(errorResponse);

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(List.of("any product"), null, null);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty(), "The resulting shop list should be empty when the API fails");
    }

    @Test
    void findShops_shouldAddRetailerAsCandidateShop_whenScraperConfirmsProductAvailability() throws IOException {
        //ARRANGE
        // Web search finds nothing useful, but the Carrefour scraper confirms the product is actually sold there.
        when(webSearchService.findShopLocations("milk")).thenReturn(Collections.emptyList());
        when(scraperOrchestrator.tryScrapeProducts("milk", "Carrefour"))
                .thenReturn(List.of(new Product("Milk 1L", "5.99", "https://carrefour.ro/milk")));

        JsonNode carrefourResponse = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":[{\"name\":\"Carrefour Vitan\",\"geometry\":{\"location\":{\"lat\":44" +
                        ".4,\"lng\":26.1}}}]}"
        );
        when(googlePlacesClient.findPlaces("Carrefour near me", null, null)).thenReturn(carrefourResponse);

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk"), null, null);

        //ASSERT
        assertEquals(1, result.size());
        assertEquals("Carrefour Vitan", result.get(0).storeName());
        assertTrue(result.get(0).products().contains("milk"));
    }

    @Test
    void findShops_shouldReturnEmptyList_whenNoProductsAreProvided() {
        //ARRANGE
        List<String> emptyProductList = Collections.emptyList();

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(emptyProductList, null, null);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty(), "Should return an empty list for an empty product input");
    }

    @Test
    void findShops_shouldReturnEmptyList_whenProductsAreNullOrEmpty() {
        //ARRANGE

        //ACT
        List<ShopResponseDto> resultForNull = shopFinderService.findShops(null, null, null);
        List<ShopResponseDto> resultForEmpty = shopFinderService.findShops(Collections.emptyList(), null, null);


        //ASSERT
        assertNotNull(resultForNull);
        assertTrue(resultForNull.isEmpty(), "Should return an empty list for a null product input");

        assertNotNull(resultForEmpty);
        assertTrue(resultForEmpty.isEmpty(), "Should return an empty list for an empty product input");

        verify(webSearchService, never()).findShopLocations(anyString());
        verify(googlePlacesClient, never()).findPlaces(anyString(), any(), any());
    }

}
