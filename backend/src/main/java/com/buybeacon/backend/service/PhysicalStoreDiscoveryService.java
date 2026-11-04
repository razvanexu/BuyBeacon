package com.buybeacon.backend.service;

import java.util.List;

public interface PhysicalStoreDiscoveryService {
    List<PhysicalStoreCandidate> findNearby(String categoryCode, double latitude, double longitude);
}
