package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.ShopLocationDto;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.util.Optional;

/**
 * A mock implementation for the geocoding service.
 * Simulates the behaviour of a real geocoding service by returning
 * a hardcoded location for avoiding the need for a real API key in
 * development and testing
 */
@Service
@Profile("test")
public class MockGeocodingServiceImp implements GeocodingService {
    @Override
    public Optional<ShopLocationDto> geocode(String locationQuery) {
        //replace with HTTP call for service like Google Geocoding API.
        if(locationQuery != null || !locationQuery.isBlank()){
            return Optional.of(new ShopLocationDto("Auchan", 44.46737908810667, 26.07814219072258));
        }
        return Optional.empty();
    }
}
