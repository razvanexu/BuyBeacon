package com.buybeacon.backend.service;

import com.buybeacon.backend.entity.ProductCategorySubmission;
import com.buybeacon.backend.repository.ProductCategorySubmissionJpaRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Postgres/JPA-backed adapter for ProductCategoryStore. The only place in the application
 * that knows persistence is JPA and that category resolution is a majority vote across
 * submissions — everything above this (ProductCategoryService, controllers) only sees the
 * ProductCategoryStore interface.
 */
@Service
public class JpaProductCategoryStore implements ProductCategoryStore {

    private final ProductCategorySubmissionJpaRepository repository;

    public JpaProductCategoryStore(ProductCategorySubmissionJpaRepository repository) {
        this.repository = repository;
    }

    @Override
    public Optional<String> findCategory(String normalizedProduct) {
        List<String> ranked = repository.findRankedCategories(normalizedProduct);
        return ranked.isEmpty() ? Optional.empty() : Optional.of(ranked.get(0));
    }

    @Override
    public void save(String normalizedProduct, String placesType) {
        repository.save(new ProductCategorySubmission(normalizedProduct, placesType, Instant.now()));
    }
}
