package com.buybeacon.backend.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/**
 * * Represents the incoming request from the mobile app.
 *
 * @param products  - a list of product names to search for.
 * @param latitude  - the user's current latitude, used to bias shop search results
 *                  to nearby stores. Null if unavailable (falls back to
 *                  IP-based geolocation of the server).
 * @param longitude - the user's current longitude, see {@code latitude}.
 */
public record ProductSearchRequestDto(
        @Schema(description = "Product names to search for", example = "[\"lapte\", \"pâine\"]")
        List<String> products,
        @Schema(description = "User's latitude, biases search to nearby stores;" +
                " null falls back to server IP geolocation", example = "44.4268")
        Double latitude, @Schema(description = "User's longitude, see latitude", example = "26.1025")
        Double longitude) {
}
