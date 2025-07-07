package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopLocationDto;

import java.util.List;

public interface ShopFinderService {
    /**
     * Takes a list of product names and returns a list of unique geographic coordinates for potential shops.
     * @param products A list of product names.
     * @return A list of uniques ShopLocationDto objects.
     */
    List<ShopLocationDto> findShops(List<String> products);
}
