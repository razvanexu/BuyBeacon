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
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Dependency injection for WebSearchService and GeocodingService;
 */
@Service
public class ShopFinderServiceImp implements ShopFinderService{
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderServiceImp.class);

    private final WebSearchService webSearchService;
    private final GooglePlacesClient googlePlacesClient;

    public ShopFinderServiceImp(WebSearchService webSearchService, GooglePlacesClient googlePlacesClient) {
        this.webSearchService = webSearchService;
        this.googlePlacesClient = googlePlacesClient;
    }

    @Override
    public List<ShopResponseDto> findShops(List<String> products) {
        Map<String, List<String>> productToShopNames = products.stream()
                        .collect(Collectors.toMap(
                                product -> product,
                                webSearchService::findShopLocations
                        ));

        Map<String, List<String>> shopNameToProducts = productToShopNames
                .entrySet().stream()
                        .flatMap(entry -> entry.getValue()
                                .stream()
                                .map(shopName -> Map.entry(shopName, entry.getKey())))
                                .collect(Collectors.groupingBy(
                                        Map.Entry::getKey,
                                        Collectors.mapping(Map.Entry::getValue, Collectors.toList())
                                ));
        logger.info("Found {} unique potential shop names from web search.", shopNameToProducts.size());

        List<String> potentialShopNames = products.stream()
                .flatMap(product -> webSearchService.findShopLocations(product).stream())
                .distinct()
                .toList();
        logger.info("Found {} unique potential shop names from web search.", potentialShopNames.size());

        List<ShopResponseDto> allShops = new ArrayList<>();
        for(Map.Entry<String, List<String>> entry : shopNameToProducts.entrySet()){
            String shopName = entry.getKey();
            List<String> associatedProducts = entry.getValue();
            try{
                logger.info("Querying Google Places API for shop: '{}'", shopName);
                JsonNode response = googlePlacesClient.findPlaces(shopName + " near me");
                logger.info("Google Places API raw response for '{}'", shopName);

                String status = response.path("status").asText();
                if(!"OK".equals(status) && !"ZERO_RESULTS".equals(status)){
                    logger.error("Google Places API returned error status: {} for query: {}", status, shopName);
                    throw new ApiException("Google Places API error: " + status, HttpStatus.BAD_GATEWAY);
                }

                if("OK".equals(status)){
                    for(JsonNode result : response.path("results")){
                        String name = result.path("name").asText();
                        JsonNode location = result.path("geometry").path("location");
                        allShops.add(new ShopResponseDto(name,
                                location.path("lat").asDouble(),
                                location.path("lng").asDouble(),
                                associatedProducts));
                    }
                }
            }catch (Exception e){
                logger.error("Error querying Google Places API for shop: '{}'", shopName, e);
            }
        }
        return allShops.stream().distinct().toList();
    }
}
