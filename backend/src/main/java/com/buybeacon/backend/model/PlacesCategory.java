package com.buybeacon.backend.model;

import java.util.Optional;

/**
 * Fixed, closed set of shop categories a user can pick when categorizing a new product.
 * Deliberately not free text: prevents duplicate/synonymous categories (e.g. two different
 * entries meaning "clothing store") and keeps every category mapped to a real Google Places
 * type, so WebSearchServiceImp can pass it straight to Places Nearby Search.
 */
public enum PlacesCategory {
    SUPERMARKET("supermarket", "Alimentar"),
    HARDWARE_STORE("hardware_store", "Bricolaj"),
    PHARMACY("pharmacy", "Farmacie"),
    ELECTRONICS_STORE("electronics_store", "Electronice"),
    CLOTHING_STORE("clothing_store", "Îmbrăcăminte"),
    PET_STORE("pet_store", "Animale de companie"),
    BOOK_STORE("book_store", "Cărți"),
    STORE("store", "General / Altele");

    private final String code;
    private final String label;

    PlacesCategory(String code, String label) {
        this.code = code;
        this.label = label;
    }

    public String getCode() {
        return code;
    }

    public String getLabel() {
        return label;
    }

    public static Optional<PlacesCategory> fromCode(String code) {
        for (PlacesCategory category : values()) {
            if (category.code.equalsIgnoreCase(code)) {
                return Optional.of(category);
            }
        }
        return Optional.empty();
    }
}
