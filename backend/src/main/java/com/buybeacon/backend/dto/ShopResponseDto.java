package com.buybeacon.backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

public record ShopResponseDto(
        @Schema(description = "Shop name as returned by Google Places") String storeName,
        @Schema(example = "44.4285") double latitude,
        @Schema(example = "26.1024") double longitude,
        @Schema(description = "Subset of requested products this shop is expected to carry")
        List<String> products,
        @Schema(description = "Discovery source: google_places, openstreetmap or retailer_catalog")
        String source,
        @Schema(description = "Evidence level: CATEGORY_MATCH or RETAILER_CATALOG")
        String matchConfidence
) {
    public ShopResponseDto(String storeName, double latitude, double longitude, List<String> products) {
        this(storeName, latitude, longitude, products, "unknown", "CATEGORY_MATCH");
    }
}
