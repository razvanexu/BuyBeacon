package com.buybeacon.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Profile("test")
public class MockWebSearchServiceImp implements WebSearchService{
    private static final Logger logger = LoggerFactory.getLogger(MockWebSearchServiceImp.class);

    @Override
    public List<DiscoveredShop> findShopLocations(String product, Double latitude, Double longitude) {
        logger.info("MOCK Web Search: Received request for product '{}'. Returning hardcoded list.", product);
        return List.of(
                new DiscoveredShop("Mega Image Concept store (Mock)", 44.4268, 26.1025, "mock-mega-image"),
                new DiscoveredShop("Carrefour Market (Mock)", 44.4300, 26.1100, "mock-carrefour"),
                new DiscoveredShop("Lidl Discount (Mock)", 44.4350, 26.0950, "mock-lidl"));
    }
}
