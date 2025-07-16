package com.buybeacon.backend.service;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.dto.ShopLocationDto;
import com.buybeacon.backend.exception.ApiException;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

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
    public List<ShopLocationDto> findShops(List<String> products) {
        logger.info("Finding shops for {} products: {}", products.size(), products);

        List<String> potentialShopNames = products.stream()
                .flatMap(product -> webSearchService.findShopLocations(product).stream())
                .distinct()
                .toList();
        logger.info("Found {} unique potential shop names from web search.", potentialShopNames.size());

        List<ShopLocationDto> allShops = new ArrayList<>();
        for(String shopName : potentialShopNames){
            try{
                logger.info("Querying Google Places API for shop: '{}'", shopName);
                JsonNode response = googlePlacesClient.findPlaces(shopName + " near me");

                if(response == null){
                    throw new ApiException("No response from Google Places API for query: " + shopName, HttpStatus.SERVICE_UNAVAILABLE);
                }

                String status = response.path("status").asText();
                if(!"OK".equals(status) && !"ZERO_RESULTS".equals(status)){
                    logger.error("Google Places API returned error status: {} for query: {}", status, shopName);
                    throw new ApiException("Google Places API error: " + status, HttpStatus.BAD_GATEWAY);
                }

                if("OK".equals(status)){
                    for(JsonNode result : response.path("name")){
                        String name = result.path("name").asText();
                        JsonNode location = result.path("geometry").path("location");
                        allShops.add(new ShopLocationDto(name,
                                location.path("lat").asDouble(),
                                location.path("lng").asDouble()));
                    }
                }
            }catch (Exception e){
                logger.error("Error querying Google Places API for shop: '{}'", shopName, e);
            }
        }
        return allShops.stream().distinct().toList();
    }
}
