package com.buybeacon.backend.service;

import com.buybeacon.backend.repository.ProductCategorySubmissionJpaRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.context.annotation.Import;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@DataJpaTest
@Import(JpaProductCategoryStore.class)
class JpaProductCategoryStoreTest {

    @Autowired
    private ProductCategorySubmissionJpaRepository repository;

    @Autowired
    private JpaProductCategoryStore store;

    @Test
    void findCategory_shouldReturnEmpty_whenNoSubmissions() {
        Optional<String> result = store.findCategory("nonexistent");

        assertTrue(result.isEmpty());
    }

    @Test
    void findCategory_shouldReturnTheOnlySubmission_whenOnlyOneExists() {
        store.save("ciocan", "hardware_store");

        Optional<String> result = store.findCategory("ciocan");

        assertTrue(result.isPresent());
        assertEquals("hardware_store", result.get());
    }

    @Test
    void save_shouldNotOverwrite_multipleSubmissionsArePersisted() {
        store.save("lapte", "pharmacy");
        store.save("lapte", "supermarket");

        assertEquals(2, repository.count());
    }

    @Test
    void findCategory_shouldReturnMajorityCategory_whenSubmissionsDisagree() {
        store.save("lapte", "pharmacy");
        store.save("lapte", "supermarket");
        store.save("lapte", "supermarket");

        Optional<String> result = store.findCategory("lapte");

        assertTrue(result.isPresent());
        assertEquals("supermarket", result.get());
    }
}
