package com.buybeacon.backend.service;

import com.buybeacon.backend.dto.NominatimResponseDto;
import com.buybeacon.backend.dto.ShopLocationDto;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.Optional;
import org.slf4j.Logger;

@Service
@Profile("!test")
public class NominatimGeocodingServiceImp implements GeocodingService{
    private static final Logger logger = LoggerFactory.getLogger(NominatimGeocodingServiceImp.class);
    private static final String NOMINATIM_API_URL = "https://nominatim.openstreetmap.org/search";

    private final RestTemplate restTemplate;

    /**
     * Injects the RestTemplateBuilder to construct a RestTemplate instance.
     * This is the recommended, thread-safe approach.
     * @param restTemplateBuilder The builder provided by Spring Boot.
     */
    @Autowired
    public NominatimGeocodingServiceImp(RestTemplateBuilder restTemplateBuilder) {
        this.restTemplate = restTemplateBuilder.build();
    }

    @Override
    public Optional<ShopLocationDto> geocode(String locationQuery) {
        String url = UriComponentsBuilder.fromUriString(NOMINATIM_API_URL)
                .queryParam("q", locationQuery)
                .queryParam("format", "json")
                .queryParam("limit", 1)
                .toUriString();

        try{
            NominatimResponseDto[] responseDto = restTemplate.getForObject(url, NominatimResponseDto[].class);

            if(responseDto != null && responseDto.length > 0){
                NominatimResponseDto topResults = responseDto[0];
                String name = topResults.getName();
                double latitude = Double.parseDouble(topResults.getLatitude());
                double longitude = Double.parseDouble(topResults.getLongitude());
                logger.info("Successfully geocoded '{}' to [lat: {}, lon: {}]", locationQuery, latitude, longitude);
                return Optional.of(new ShopLocationDto(name, latitude, longitude));
            } else {
                logger.warn("No geocoding results found from address: {}", locationQuery);
                return Optional.empty();
            }
        }catch (Exception e){
            logger.error("Error during geocoding for address: {}", locationQuery, e);
            return Optional.empty();
        }
    }
}
