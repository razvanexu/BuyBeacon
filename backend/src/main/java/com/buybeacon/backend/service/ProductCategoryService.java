package com.buybeacon.backend.service;

import com.buybeacon.backend.model.PlacesCategory;

import java.util.List;
import java.util.Optional;

public interface ProductCategoryService {

    /**
     * @return the crowdsourced category for this product, if it has any submissions.
     */
    Optional<String> lookupCategory(String product);

    /**
     * Records a category submission for a product.
     *
     * @throws com.buybeacon.backend.exception.ApiException if placesTypeCode isn't one of PlacesCategory's codes.
     */
    void saveCategory(String product, String placesTypeCode);

    /**
     * @return the fixed, closed list of categories a user can pick from.
     */
    List<PlacesCategory> listCategories();
}
