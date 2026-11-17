package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopResponseDto;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

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

    @Mock
    private WebSearchService webSearchService;

    private ExecutorService executorService;
    private ShopFinderServiceImp shopFinderService;

    @BeforeEach
    void setUp() {
        // Single-threaded executor keeps test execution deterministic while still exercising
        // the same CompletableFuture-based code path used in production.
        executorService = Executors.newSingleThreadExecutor();
        shopFinderService = new ShopFinderServiceImp(webSearchService, executorService);
    }

    @AfterEach
    void tearDown() {
        executorService.shutdown();
    }

    @Test
    void findShops_shouldReturnDiscoveredShopsWithTheirCoordinatesAndEvidence() {
        when(webSearchService.findShopLocations("milk", 44.456, 26.073)).thenReturn(List.of(
                new DiscoveredShop("Carrefour Vitan", 44.4, 26.1, "place1"),
                new DiscoveredShop("Mic magazin", 44.457, 26.074, "osm:node:42")
        ));

        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk"), 44.456, 26.073);

        assertEquals(2, result.size());
        ShopResponseDto places = shopNamed(result, "Carrefour Vitan");
        assertEquals(44.4, places.latitude());
        assertEquals(26.1, places.longitude());
        assertEquals(List.of("milk"), places.products());
        assertEquals("google_places", places.source());
        assertEquals("CATEGORY_MATCH", places.matchConfidence());

        ShopResponseDto osm = shopNamed(result, "Mic magazin");
        assertEquals("openstreetmap", osm.source());
        assertEquals("CATEGORY_MATCH", osm.matchConfidence());
    }

    @Test
    void findShops_shouldMergeTheSameShopAcrossProducts() {
        when(webSearchService.findShopLocations("milk", null, null)).thenReturn(List.of(
                new DiscoveredShop("Carrefour Vitan", 44.4, 26.1, "place1"),
                new DiscoveredShop("Mega Image Unirii", 44.42, 26.11, "place2")));
        when(webSearchService.findShopLocations("bread", null, null)).thenReturn(List.of(
                new DiscoveredShop("Carrefour Vitan", 44.4, 26.1, "place1"),
                new DiscoveredShop("Lidl Discount", 44.45, 26.05, "place3")));

        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk", "bread"), null, null);

        assertEquals(3, result.size(), "Should find 3 unique shops");
        assertEquals(List.of("milk", "bread"), shopNamed(result, "Carrefour Vitan").products());
        assertEquals(List.of("milk"), shopNamed(result, "Mega Image Unirii").products());
        assertEquals(List.of("bread"), shopNamed(result, "Lidl Discount").products());
    }

    @Test
    void findShops_shouldKeepSeparateBranchesThatShareADisplayName() {
        // Chains reuse the exact same name for many branches; identity is the place id, not the name.
        when(webSearchService.findShopLocations("milk", null, null)).thenReturn(List.of(
                new DiscoveredShop("Mega Image", 44.40, 26.10, "branchA"),
                new DiscoveredShop("Mega Image", 44.41, 26.12, "branchB")));

        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk"), null, null);

        assertEquals(2, result.size());
        assertTrue(result.stream().anyMatch(s -> s.latitude() == 44.40 && s.longitude() == 26.10));
        assertTrue(result.stream().anyMatch(s -> s.latitude() == 44.41 && s.longitude() == 26.12));
    }

    @Test
    void findShops_shouldSkipCandidatesWithoutCoordinates() {
        when(webSearchService.findShopLocations("milk", null, null)).thenReturn(List.of(
                new DiscoveredShop("Nameless location", null, null, null),
                new DiscoveredShop("Lidl Discount", 44.45, 26.05, "place3")));

        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk"), null, null);

        assertEquals(1, result.size());
        assertEquals("Lidl Discount", result.get(0).storeName());
    }

    @Test
    void findShops_shouldNeverReturnRetailerCatalogResults() {
        when(webSearchService.findShopLocations(anyString(), any(), any())).thenReturn(List.of(
                new DiscoveredShop("Carrefour Vitan", 44.4, 26.1, "place1"),
                new DiscoveredShop("Mic magazin", 44.457, 26.074, "osm:node:42")));

        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk", "bread"), null, null);

        assertFalse(result.isEmpty());
        assertTrue(result.stream().noneMatch(s -> "retailer_catalog".equals(s.source())));
        assertTrue(result.stream().noneMatch(s -> "RETAILER_CATALOG".equals(s.matchConfidence())));
    }

    @Test
    void findShops_shouldReturnEmptyList_whenNothingIsFound() {
        when(webSearchService.findShopLocations("milk", null, null)).thenReturn(Collections.emptyList());

        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk"), null, null);

        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void findShops_shouldReturnEmptyList_whenProductsAreNullOrEmpty() {
        List<ShopResponseDto> resultForNull = shopFinderService.findShops(null, null, null);
        List<ShopResponseDto> resultForEmpty = shopFinderService.findShops(Collections.emptyList(), null, null);

        assertNotNull(resultForNull);
        assertTrue(resultForNull.isEmpty(), "Should return an empty list for a null product input");
        assertNotNull(resultForEmpty);
        assertTrue(resultForEmpty.isEmpty(), "Should return an empty list for an empty product input");
        verify(webSearchService, never()).findShopLocations(anyString(), any(), any());
    }

    private static ShopResponseDto shopNamed(List<ShopResponseDto> shops, String name) {
        return shops.stream()
                .filter(s -> s.storeName().equals(name))
                .findFirst()
                .orElseThrow(() -> new AssertionError(name + " should be in the list"));
    }
}
