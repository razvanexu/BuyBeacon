package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopLocationDto;
import java.util.Optional;

public interface GeocodingService {
    /**
     * Converts a location query string (like an address or place name) into geographic coordinates.
     *
     * @param locationQuery The address or name of the place to geocode.
     * @return An Optional containing the ShopLocationDto if coordinates are found, otherwise an empty Optional.
     */
    Optional<ShopLocationDto> geocode(String locationQuery);
}
