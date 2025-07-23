package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.dto.ShopResponseDto;
import com.buybeacon.backend.exception.ApiException;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Dependency injection for WebSearchService and GeocodingService;
 */
@Service
public class ShopFinderServiceImp implements ShopFinderService {
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderServiceImp.class);

    private final WebSearchService webSearchService;
    private final GooglePlacesClient googlePlacesClient;

    public ShopFinderServiceImp(WebSearchService webSearchService, GooglePlacesClient googlePlacesClient) {
        this.webSearchService = webSearchService;
        this.googlePlacesClient = googlePlacesClient;
    }

    private static Map<String, List<String>> getShopToProducts(Map<String, List<String>> productToShopNames) {
        return productToShopNames
                .entrySet()
                .stream()
                .flatMap(entry -> entry.getValue()
                        .stream()
                        .map(shopName -> Map.entry(shopName, entry.getKey())))
                .collect(Collectors.groupingBy(
                        Map.Entry::getKey,
                        Collectors.mapping(Map.Entry::getValue, Collectors.toList())
                ));
    }

    private String isSuccessfulResponse(JsonNode response, String shopName) {
        String status = response.path("status").asText();
        if (!"OK".equals(status) && !"ZERO_RESULTS".equals(status)) {
            logger.error("Google Places API returned error status: {} for query: {}", status, shopName);
            throw new ApiException("Google Places API error: " + status, HttpStatus.BAD_GATEWAY);
        }
        return status;
    }

    private void createShopResponseDto(String status, JsonNode response, List<ShopResponseDto> allShops,
                                       List<String> associatedProducts) {
        if ("OK".equals(status)) {
            for (JsonNode result : response.path("results")) {
                String name = result.path("name").asText();
                JsonNode location = result.path("geometry").path("location");
                allShops.add(new ShopResponseDto(name,
                        location.path("lat").asDouble(),
                        location.path("lng").asDouble(),
                        associatedProducts));
            }
        }
    }

    @Override
    public List<ShopResponseDto> findShops(List<String> products) {
        if (products == null || products.isEmpty()) {
            logger.warn("findShops called with a null or empty list");
            return Collections.emptyList();
        }
        Map<String, List<String>> productToShopNames = products.stream()
                .collect(Collectors.toMap(
                        product -> product,
                        webSearchService::findShopLocations
                ));

        Map<String, List<String>> shopNameToProducts = getShopToProducts(productToShopNames);
        logger.info("Found {} unique potential shop names from web search.", shopNameToProducts.size());

        return getGeocodedShops(shopNameToProducts);
    }

    private List<ShopResponseDto> getGeocodedShops(Map<String, List<String>> shopNameToProducts) {
        List<ShopResponseDto> allShops = new ArrayList<>();
        for (Map.Entry<String, List<String>> entry : shopNameToProducts.entrySet()) {
            String shopName = entry.getKey();
            List<String> associatedProducts = entry.getValue();
            try {
                logger.info("Querying Google Places API for shop: '{}'", shopName);
                JsonNode response = googlePlacesClient.findPlaces(shopName + " near me");

                String status = isSuccessfulResponse(response, shopName);

                createShopResponseDto(status, response, allShops, associatedProducts);
            } catch (Exception e) {
                logger.error("Error querying Google Places API for shop: '{}'", shopName, e);
            }
        }
        return allShops.stream().distinct().toList();
    }
}
