package com.buybeacon.backend.service;

import com.buybeacon.backend.exception.ApiException;
import com.buybeacon.backend.model.PlacesCategory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

@Service
public class ProductCategoryServiceImp implements ProductCategoryService {

    private static final Pattern DIACRITICS = Pattern.compile("\\p{M}");

    private final ProductCategoryStore productCategoryStore;

    public ProductCategoryServiceImp(ProductCategoryStore productCategoryStore) {
        this.productCategoryStore = productCategoryStore;
    }

    @Override
    public Optional<String> lookupCategory(String product) {
        if (product == null || product.isBlank()) {
            return Optional.empty();
        }
        return productCategoryStore.findCategory(normalize(product));
    }

    @Override
    public void saveCategory(String product, String placesTypeCode) {
        if (product == null || product.isBlank()) {
            throw new ApiException("Product name must not be blank", HttpStatus.BAD_REQUEST);
        }
        PlacesCategory category = PlacesCategory.fromCode(placesTypeCode)
                .orElseThrow(() -> new ApiException("Unknown category code: " + placesTypeCode, HttpStatus.BAD_REQUEST));
        productCategoryStore.save(normalize(product), category.getCode());
    }

    @Override
    public List<PlacesCategory> listCategories() {
        return Arrays.asList(PlacesCategory.values());
    }

    private String normalize(String product) {
        String stripped = DIACRITICS.matcher(Normalizer.normalize(product, Normalizer.Form.NFD)).replaceAll("");
        return stripped.trim().toLowerCase();
    }
}
