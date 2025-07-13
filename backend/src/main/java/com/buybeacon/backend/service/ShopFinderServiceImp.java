package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopLocationDto;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Dependency injection for WebSearchService and GeocodingService;
 */
@Service
public class ShopFinderServiceImp implements ShopFinderService{
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderServiceImp.class);

    private final WebSearchService webSearchService;
    private final GeocodingService geocodingService;

    public ShopFinderServiceImp(WebSearchService webSearchService, GeocodingService geocodingService) {
        this.webSearchService = webSearchService;
        this.geocodingService = geocodingService;
    }

    @Override
    public List<ShopLocationDto> findShops(List<String> products) {
        logger.info("Finding shops for {} products: {}", products.size(), products);

        List<ShopLocationDto> foundShops = products.stream()
                //transforms a stream of products into a stream of individual shop locations
                .flatMap(product -> webSearchService.findShopLocations(product).stream())
                .distinct()//process each store name only once
                //for each shop location call geocodingService
                .map(shopName -> {
                    logger.info("Attempting to geocode store '{}'", shopName);
                    return geocodingService.geocode(shopName);
                })
                //filter out any locations the geocoding couldn't find
                .filter(Optional::isPresent)
                //get the ShopLocationDto from the Optional
                .map(Optional::get)
                //avoid duplicates
                .distinct()
                .collect(Collectors.toList());
        logger.info("Returning {} unique shop locations", foundShops);
        return foundShops;
    }
}
