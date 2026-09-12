package com.buybeacon.backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record CategoryOptionDto(
        @Schema(description = "Category code (Places type)", example = "supermarket")
        String value,
        @Schema(description = "Human-readable label shown in the picker UI",
                example = "Alimentar")
        String label) {
}