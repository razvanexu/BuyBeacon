package com.buybeacon.backend.dto;

import java.util.List;

/**
 * * Represents the incoming request from the mobile app.
 * @param products - a list of product names to search for.
 */
public record ProductSearchRequestDto(List<String> products) {
}
