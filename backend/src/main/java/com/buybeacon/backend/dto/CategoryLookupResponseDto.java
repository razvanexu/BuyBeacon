package com.buybeacon.backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record CategoryLookupResponseDto(
        @Schema(description = "Whether this product name is already in the category dictionary")
        boolean known,
        @Schema(description = "The matched category code, null if unknown", example = "supermarket")
        String category) {
}
