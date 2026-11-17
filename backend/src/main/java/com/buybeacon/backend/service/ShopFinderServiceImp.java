package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopResponseDto;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.stream.Collectors;

/**
 * Orchestrates shop discovery for a list of products: runs {@link WebSearchService} (Google Places
 * + OpenStreetMap) per product, then merges the candidates into one list of shops, each carrying
 * every requested product it matched.
 */
@Service
public class ShopFinderServiceImp implements ShopFinderService {
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderServiceImp.class);

    private final WebSearchService webSearchService;
    private final ExecutorService scrapingExecutor;

    public ShopFinderServiceImp(WebSearchService webSearchService,
                                @Qualifier("scrapingExecutor") ExecutorService scrapingExecutor) {
        this.webSearchService = webSearchService;
        this.scrapingExecutor = scrapingExecutor;
    }

    @Override
    public List<ShopResponseDto> findShops(List<String> products, Double latitude, Double longitude) {
        if (products == null || products.isEmpty()) {
            logger.warn("findShops called with a null or empty list");
            return Collections.emptyList();
        }

        // Each product's discovery is independent, so run them concurrently on the bounded
        // scrapingExecutor rather than one after another.
        List<CompletableFuture<Map.Entry<String, List<DiscoveredShop>>>> discoveryFutures = products.stream()
                .map(product -> CompletableFuture.supplyAsync(
                        () -> Map.entry(product, findShopsForProduct(product, latitude, longitude)), scrapingExecutor))
                .toList();

        Map<String, List<DiscoveredShop>> productToShops = discoveryFutures.stream()
                .map(CompletableFuture::join)
                .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue, (a, b) -> a, LinkedHashMap::new));

        // Group discoveries by shop identity (Places place_id / OSM id, across all products) --
        // NOT by name, since chains like Mega Image/Carrefour Express/Froo reuse the exact same
        // display name across dozens of distinct physical branches in the same city; keying by
        // name alone would silently collapse separate nearby branches into a single pin.
        Map<String, List<String>> shopKeyToProducts = new LinkedHashMap<>();
        Map<String, DiscoveredShop> shopByKey = new LinkedHashMap<>();
        for (Map.Entry<String, List<DiscoveredShop>> entry : productToShops.entrySet()) {
            String product = entry.getKey();
            for (DiscoveredShop shop : entry.getValue()) {
                String key = shop.identityKey();
                shopKeyToProducts.computeIfAbsent(key, k -> new ArrayList<>()).add(product);
                shopByKey.putIfAbsent(key, shop);
            }
        }

        List<ShopResponseDto> shops = new ArrayList<>();
        for (Map.Entry<String, List<String>> entry : shopKeyToProducts.entrySet()) {
            DiscoveredShop shop = shopByKey.get(entry.getKey());
            if (!shop.hasCoordinates()) {
                logger.warn("Skipping shop candidate '{}' without coordinates", shop.name());
                continue;
            }
            shops.add(new ShopResponseDto(shop.name(), shop.latitude(), shop.longitude(), entry.getValue(),
                    shop.source(), shop.matchConfidence()));
        }
        logger.info("Returning {} shops out of {} candidates: {}",
                shops.size(), shopKeyToProducts.size(), shops.stream().map(ShopResponseDto::storeName).toList());
        return shops;
    }

    private List<DiscoveredShop> findShopsForProduct(String product, Double latitude, Double longitude) {
        Map<String, DiscoveredShop> shops = new LinkedHashMap<>();
        for (DiscoveredShop shop : webSearchService.findShopLocations(product, latitude, longitude)) {
            shops.put(shop.identityKey(), shop);
        }
        return new ArrayList<>(shops.values());
    }
}
