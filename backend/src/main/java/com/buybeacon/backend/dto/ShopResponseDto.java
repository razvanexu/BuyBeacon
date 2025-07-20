package com.buybeacon.backend.dto;

import java.util.List;

public record ShopResponseDto(String storeName, double latitude, double longitude, List<String> products) {
}
