package com.buybeacon.backend.dto;

import java.util.List;

/**
 * * Represents the incoming request from the mobile app.
 * @param products - a list of product names to search for.
 * @param latitude - the user's current latitude, used to bias shop search results
 *                    to nearby stores. Null if unavailable (falls back to
 *                    IP-based geolocation of the server).
 * @param longitude - the user's current longitude, see {@code latitude}.
 */
public record ProductSearchRequestDto(List<String> products, Double latitude, Double longitude) {
}
