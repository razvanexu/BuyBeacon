package com.buybeacon.backend.service;

/**
 * A customer-facing physical store. Product relevance is inferred from its
 * category; this record does not claim that a branch has stock.
 */
public record PhysicalStoreCandidate(
        String sourceId,
        String name,
        double latitude,
        double longitude,
        String storeType,
        String source
) {
}
