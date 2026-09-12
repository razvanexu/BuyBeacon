package com.buybeacon.backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record SaveCategoryRequestDto(
        @Schema(description = "Product name, must not be blank", example = "lapte")
        String product,
        @Schema(description = "Category code, one of PlacesCategory's values",
                example = "supermarket")
        String category) {
}
