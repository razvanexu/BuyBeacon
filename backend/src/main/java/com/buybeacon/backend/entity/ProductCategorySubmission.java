package com.buybeacon.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;

import java.time.Instant;

/**
 * A single user submission mapping a product to a Places category. Multiple submissions
 * per product are expected and intentional (see ProductCategoryStore) — the winning
 * category for a product is decided by majority vote across submissions, not by the
 * first one written, so a single bad-faith or mistaken entry can't permanently corrupt
 * the shared classification for everyone.
 */
@Entity
@Table(name = "product_category_submission", indexes = @Index(name = "idx_normalized_product", columnList = "normalizedProduct"))
public class ProductCategorySubmission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String normalizedProduct;

    @Column(nullable = false)
    private String placesType;

    @Column(nullable = false)
    private Instant submittedAt;

    protected ProductCategorySubmission() {
        // JPA
    }

    public ProductCategorySubmission(String normalizedProduct, String placesType, Instant submittedAt) {
        this.normalizedProduct = normalizedProduct;
        this.placesType = placesType;
        this.submittedAt = submittedAt;
    }

    public Long getId() {
        return id;
    }

    public String getNormalizedProduct() {
        return normalizedProduct;
    }

    public String getPlacesType() {
        return placesType;
    }

    public Instant getSubmittedAt() {
        return submittedAt;
    }
}
