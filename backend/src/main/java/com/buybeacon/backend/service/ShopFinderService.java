package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopResponseDto;

import java.util.List;

public interface ShopFinderService {
    /**
     * Takes a list of product names and returns a list of unique geographic coordinates for potential shops.
     * @param products A list of product names.
     * @param latitude The user's current latitude, used to bias results to nearby stores. May be null.
     * @param longitude The user's current longitude. May be null.
     * @return A list of uniques {@link ShopResponseDto} objects.
     */
    List<ShopResponseDto> findShops(List<String> products, Double latitude, Double longitude);
}
