package com.buybeacon.backend.repository;

import com.buybeacon.backend.entity.ProductCategorySubmission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ProductCategorySubmissionJpaRepository extends JpaRepository<ProductCategorySubmission, Long> {

    /**
     * Categories submitted for a product, ranked by number of submissions (most first).
     * The winning category is the head of this list — see JpaProductCategoryStore.
     */
    @Query("SELECT s.placesType FROM ProductCategorySubmission s WHERE s.normalizedProduct = :product "
            + "GROUP BY s.placesType ORDER BY COUNT(s) DESC")
    List<String> findRankedCategories(@Param("product") String normalizedProduct);
}
