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
    public List<String> findShopLocations(String product) {
        logger.info("MOCK Web Search: Received request for product '{}'. Returning hardcoded list.", product);
        return List.of("Mega Image Concept store (Mock)",
                "Carrefour Market (Mock)",
                "Lidl Discount (Mock)");
    }
}
