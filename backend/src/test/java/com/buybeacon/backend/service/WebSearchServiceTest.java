package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WebSearchServiceTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private GooglePlacesClient googlePlacesClient;

    @Mock
    private ProductCategoryService productCategoryService;

    @InjectMocks
    private WebSearchServiceImp webSearchService;

    @Test
    void findShopLocations_shouldUseKnownCategory_whenPresent() throws Exception {
        //ARRANGE
        when(productCategoryService.lookupCategory("ciocan")).thenReturn(Optional.of("hardware_store"));
        JsonNode response = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":["
                        + "{\"name\":\"Dedeman\",\"geometry\":{\"location\":{\"lat\":44.4,\"lng\":26.1}}},"
                        + "{\"name\":\"Leroy Merlin\",\"geometry\":{\"location\":{\"lat\":44.41,\"lng\":26.11}}}"
                        + "]}"
        );
        when(googlePlacesClient.findNearbyPlaces("hardware_store", 44.4, 26.1)).thenReturn(response);

        //ACT
        List<DiscoveredShop> result = webSearchService.findShopLocations("ciocan", 44.4, 26.1);

        //ASSERT
        assertNotNull(result);
        assertEquals(2, result.size());
        assertEquals("Dedeman", result.get(0).name());
        assertEquals(44.4, result.get(0).latitude());
        assertEquals(26.1, result.get(0).longitude());
        assertEquals("Leroy Merlin", result.get(1).name());

        verify(googlePlacesClient).findNearbyPlaces("hardware_store", 44.4, 26.1);
    }

    @Test
    void findShopLocations_shouldFallbackToGenericStore_whenCategoryUnknown() throws Exception {
        //ARRANGE
        when(productCategoryService.lookupCategory("unobtainium")).thenReturn(Optional.empty());
        JsonNode response = objectMapper.readTree("{\"status\":\"OK\",\"results\":[]}");
        when(googlePlacesClient.findNearbyPlaces("store", 44.4, 26.1)).thenReturn(response);

        //ACT
        webSearchService.findShopLocations("unobtainium", 44.4, 26.1);

        //ASSERT
        verify(googlePlacesClient).findNearbyPlaces("store", 44.4, 26.1);
    }

    @Test
    void findShopLocations_shouldReturnEmptyList_whenCoordinatesMissing() {
        //ACT
        List<DiscoveredShop> result = webSearchService.findShopLocations("ciocan", null, null);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty());
        verify(googlePlacesClient, never()).findNearbyPlaces(anyString(), anyDouble(), anyDouble());
        verify(productCategoryService, never()).lookupCategory(anyString());
    }

    @Test
    void findShopLocations_shouldQueryBothSynonymTypes_andMergeDedupedResults_forSupermarketCategory() throws Exception {
        //ARRANGE
        // "supermarket" and "grocery_or_supermarket" are two overlapping, inconsistently-applied
        // Google Places types -- some real nearby stores only carry one of the two, so both must
        // be queried and merged (deduped by name) to avoid silently missing them.
        when(productCategoryService.lookupCategory("lapte")).thenReturn(Optional.of("supermarket"));

        JsonNode supermarketResponse = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":["
                        + "{\"name\":\"Kaufland\",\"geometry\":{\"location\":{\"lat\":44.4,\"lng\":26.1}}},"
                        + "{\"name\":\"Mega Image Domenii\",\"geometry\":{\"location\":{\"lat\":44.41,\"lng\":26.11}}}"
                        + "]}"
        );
        JsonNode groceryResponse = objectMapper.readTree(
                "{\"status\":\"OK\",\"results\":["
                        // Same name as one already found via "supermarket" -- should be deduped.
                        + "{\"name\":\"Mega Image Domenii\",\"geometry\":{\"location\":{\"lat\":44.41,\"lng\":26.11}}},"
                        + "{\"name\":\"Penny Domenii\",\"geometry\":{\"location\":{\"lat\":44.42,\"lng\":26.12}}}"
                        + "]}"
        );
        when(googlePlacesClient.findNearbyPlaces("supermarket", 44.4, 26.1)).thenReturn(supermarketResponse);
        when(googlePlacesClient.findNearbyPlaces("grocery_or_supermarket", 44.4, 26.1)).thenReturn(groceryResponse);

        //ACT
        List<DiscoveredShop> result = webSearchService.findShopLocations("lapte", 44.4, 26.1);

        //ASSERT
        assertEquals(3, result.size(), "Should have 3 unique shops after deduping the overlapping match");
        assertTrue(result.stream().anyMatch(s -> s.name().equals("Kaufland")));
        assertTrue(result.stream().anyMatch(s -> s.name().equals("Mega Image Domenii")));
        assertTrue(result.stream().anyMatch(s -> s.name().equals("Penny Domenii")));

        verify(googlePlacesClient).findNearbyPlaces("supermarket", 44.4, 26.1);
        verify(googlePlacesClient).findNearbyPlaces("grocery_or_supermarket", 44.4, 26.1);
    }

    @Test
    void findShopLocations_shouldReturnEmptyList_whenZeroResults() throws Exception {
        //ARRANGE
        when(productCategoryService.lookupCategory(anyString())).thenReturn(Optional.of("supermarket"));
        JsonNode response = objectMapper.readTree("{\"status\":\"ZERO_RESULTS\",\"results\":[]}");
        when(googlePlacesClient.findNearbyPlaces(anyString(), anyDouble(), anyDouble())).thenReturn(response);

        //ACT
        List<DiscoveredShop> result = webSearchService.findShopLocations("lapte", 44.4, 26.1);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void findShopLocations_shouldReturnEmptyList_whenApiErrorStatus() throws Exception {
        //ARRANGE
        when(productCategoryService.lookupCategory(anyString())).thenReturn(Optional.of("supermarket"));
        JsonNode response = objectMapper.readTree("{\"status\":\"REQUEST_DENIED\"}");
        when(googlePlacesClient.findNearbyPlaces(anyString(), anyDouble(), anyDouble())).thenReturn(response);

        //ACT
        List<DiscoveredShop> result = webSearchService.findShopLocations("lapte", 44.4, 26.1);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void findShopLocations_shouldReturnEmptyList_whenFindNearbyPlacesThrows() {
        //ARRANGE
        when(productCategoryService.lookupCategory(anyString())).thenReturn(Optional.of("supermarket"));
        when(googlePlacesClient.findNearbyPlaces(anyString(), anyDouble(), anyDouble()))
                .thenThrow(new RuntimeException("Network Error"));

        //ACT
        List<DiscoveredShop> result = webSearchService.findShopLocations("lapte", 44.4, 26.1);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void findShopLocations_shouldReturnEmptyList_whenNullOrBlankProduct() {
        //ACT
        List<DiscoveredShop> resultsForNull = webSearchService.findShopLocations(null, 44.4, 26.1);
        List<DiscoveredShop> resultsForBlank = webSearchService.findShopLocations("  ", 44.4, 26.1);

        //ASSERT
        assertNotNull(resultsForNull);
        assertTrue(resultsForNull.isEmpty());
        assertNotNull(resultsForBlank);
        assertTrue(resultsForBlank.isEmpty());

        verify(googlePlacesClient, never()).findNearbyPlaces(anyString(), anyDouble(), anyDouble());
    }
}
