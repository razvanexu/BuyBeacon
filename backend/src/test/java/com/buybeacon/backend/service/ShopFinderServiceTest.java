package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.dto.ShopResponseDto;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.annotation.Autowired;

import java.io.IOException;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ShopFinderServiceTest {

    @Autowired
    private final ObjectMapper objectMapper = new ObjectMapper();
    @InjectMocks
    ShopFinderServiceImp shopFinderService;
    @Mock
    private WebSearchService webSearchService;
    @Mock
    private GooglePlacesClient googlePlacesClient;

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

        when(googlePlacesClient.findPlaces("Carrefour near me")).thenReturn(carrefourResponse);
        when(googlePlacesClient.findPlaces("Mega Image near me")).thenReturn(megaImageResponse);
        when(googlePlacesClient.findPlaces("Lidl near me")).thenReturn(lidlResponse);

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(List.of("milk", "bread"));

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
        when(googlePlacesClient.findPlaces(anyString())).thenReturn(errorResponse);

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(List.of("any product"));

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty(), "The resulting shop list should be empty when the API fails");
    }

    @Test
    void findShops_shouldReturnEmptyList_whenNoProductsAreProvided() {
        //ARRANGE
        List<String> emptyProductList = Collections.emptyList();

        //ACT
        List<ShopResponseDto> result = shopFinderService.findShops(emptyProductList);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty(), "Should return an empty list for an empty product input");
    }

    @Test
    void findShops_shouldReturnEmptyList_whenProductsAreNullOrEmpty() {
        //ARRANGE

        //ACT
        List<ShopResponseDto> resultForNull = shopFinderService.findShops(null);
        List<ShopResponseDto> resultForEmpty = shopFinderService.findShops(Collections.emptyList());


        //ASSERT
        assertNotNull(resultForNull);
        assertTrue(resultForNull.isEmpty(), "Should return an empty list for a null product input");

        assertNotNull(resultForEmpty);
        assertTrue(resultForEmpty.isEmpty(), "Should return an empty list for an empty product input");

        verify(webSearchService, never()).findShopLocations(anyString());
        verify(googlePlacesClient, never()).findPlaces(anyString());
    }

}
