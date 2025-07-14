package com.buybeacon.backend.dto;

/**
 * Represents the geographic coordinates of a potential shop.
 * This is the data structure that will be sent back to the mobile app.
 * @param storeName
 * @param latitude
 * @param longitude
 */
public record ShopLocationDto(String storeName, double latitude, double longitude) {
}
