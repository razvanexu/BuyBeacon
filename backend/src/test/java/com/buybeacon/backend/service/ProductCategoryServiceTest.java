package com.buybeacon.backend.service;

import com.buybeacon.backend.exception.ApiException;
import com.buybeacon.backend.model.PlacesCategory;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductCategoryServiceTest {

    @Mock
    private ProductCategoryStore productCategoryStore;

    @InjectMocks
    private ProductCategoryServiceImp productCategoryService;

    @Test
    void lookupCategory_shouldReturnCategory_whenKnown() {
        when(productCategoryStore.findCategory("ciocan")).thenReturn(Optional.of("hardware_store"));

        Optional<String> result = productCategoryService.lookupCategory("ciocan");

        assertTrue(result.isPresent());
        assertEquals("hardware_store", result.get());
    }

    @Test
    void lookupCategory_shouldNormalize_beforeLookingUp() {
        when(productCategoryStore.findCategory("ciocan")).thenReturn(Optional.of("hardware_store"));

        productCategoryService.lookupCategory("  Ciocan  ");

        verify(productCategoryStore).findCategory("ciocan");
    }

    @Test
    void lookupCategory_shouldStripDiacritics_beforeLookingUp() {
        when(productCategoryStore.findCategory("paine")).thenReturn(Optional.of("supermarket"));

        productCategoryService.lookupCategory("pâine");

        verify(productCategoryStore).findCategory("paine");
    }

    @Test
    void lookupCategory_shouldReturnEmpty_whenUnknown() {
        when(productCategoryStore.findCategory(anyString())).thenReturn(Optional.empty());

        Optional<String> result = productCategoryService.lookupCategory("unobtainium");

        assertTrue(result.isEmpty());
    }

    @Test
    void lookupCategory_shouldReturnEmpty_whenProductNullOrBlank() {
        assertTrue(productCategoryService.lookupCategory(null).isEmpty());
        assertTrue(productCategoryService.lookupCategory("  ").isEmpty());
        verify(productCategoryStore, never()).findCategory(anyString());
    }

    @Test
    void saveCategory_shouldSaveNormalizedProduct_whenCategoryValid() {
        productCategoryService.saveCategory("Ciocan", "hardware_store");

        ArgumentCaptor<String> productCaptor = ArgumentCaptor.forClass(String.class);
        verify(productCategoryStore).save(productCaptor.capture(), org.mockito.ArgumentMatchers.eq("hardware_store"));
        assertEquals("ciocan", productCaptor.getValue());
    }

    @Test
    void saveCategory_shouldThrow_whenCategoryInvalid() {
        assertThrows(ApiException.class, () -> productCategoryService.saveCategory("ciocan", "not_a_real_category"));
        verify(productCategoryStore, never()).save(anyString(), anyString());
    }

    @Test
    void saveCategory_shouldThrow_whenProductBlank() {
        assertThrows(ApiException.class, () -> productCategoryService.saveCategory("  ", "store"));
        verify(productCategoryStore, never()).save(anyString(), anyString());
    }

    @Test
    void listCategories_shouldReturnAllFixedCategories() {
        List<PlacesCategory> categories = productCategoryService.listCategories();

        assertEquals(PlacesCategory.values().length, categories.size());
        assertTrue(categories.contains(PlacesCategory.STORE));
    }
}
