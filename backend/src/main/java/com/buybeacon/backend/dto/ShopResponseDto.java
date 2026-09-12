package com.buybeacon.backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

public record ShopResponseDto(
        @Schema(description = "Shop name as returned by Google Places") String storeName,
        @Schema(example = "44.4285") double latitude,
        @Schema(example = "26.1024") double longitude,
        @Schema(description = "Subset of requested products this shop is expected to carry")
        List<String> products
) {
}
