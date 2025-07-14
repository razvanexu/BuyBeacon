package com.buybeacon.backend.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Represents the JSON response structure of the Nominatim APIs (OpenStreetMap)
 * Extracting only lat and long position coordinates
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public class NominatimResponseDto {

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    @JsonProperty("lat")
    private String name;

    @JsonProperty
    private String latitude;

    @JsonProperty("long")
    private String longitude;

    public String getLatitude() {
        return latitude;
    }

    public void setLatitude(String latitude) {
        this.latitude = latitude;
    }

    public String getLongitude() {
        return longitude;
    }

    public void setLongitude(String longitude) {
        this.longitude = longitude;
    }
}
