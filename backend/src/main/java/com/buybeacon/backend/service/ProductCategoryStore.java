package com.buybeacon.backend.service;

import java.util.Optional;

/**
 * Persistence port for product-to-category submissions, kept deliberately agnostic of the
 * storage technology (see JpaProductCategoryStore for the current Postgres/JPA adapter).
 * Swapping storage tech means writing a new implementation of this interface — no changes
 * needed in ProductCategoryService or its callers.
 */
public interface ProductCategoryStore {

    /**
     * @return the category with the most submissions for this product, if any exist.
     */
    Optional<String> findCategory(String normalizedProduct);

    /**
     * Records a new submission for this product. Does not overwrite prior submissions —
     * the winning category is decided by majority vote (see findCategory).
     */
    void save(String normalizedProduct, String placesType);
}
