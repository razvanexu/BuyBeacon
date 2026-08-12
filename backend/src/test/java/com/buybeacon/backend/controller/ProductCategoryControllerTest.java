package com.buybeacon.backend.controller;

import com.buybeacon.backend.exception.GlobalExceptionHandler;
import com.buybeacon.backend.model.PlacesCategory;
import com.buybeacon.backend.service.ProductCategoryService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ProductCategoryControllerTest {

    @Autowired
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private ProductCategoryService productCategoryService;

    @Autowired
    private MockMvc mockMvc;

    @InjectMocks
    private ProductCategoryController productCategoryController;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.standaloneSetup(productCategoryController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void getCategory_shouldReturnKnownTrue_whenCategoryExists() throws Exception {
        when(productCategoryService.lookupCategory("ciocan")).thenReturn(Optional.of("hardware_store"));

        mockMvc.perform(get("/api/products/category").param("product", "ciocan"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.known").value(true))
                .andExpect(jsonPath("$.category").value("hardware_store"));
    }

    @Test
    void getCategory_shouldReturnKnownFalse_whenCategoryMissing() throws Exception {
        when(productCategoryService.lookupCategory("unobtainium")).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/products/category").param("product", "unobtainium"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.known").value(false));
    }

    @Test
    void saveCategory_shouldReturnOk_whenValid() throws Exception {
        Map<String, String> body = Map.of("product", "ciocan", "category", "hardware_store");

        mockMvc.perform(post("/api/products/category")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk());

        verify(productCategoryService).saveCategory("ciocan", "hardware_store");
    }

    @Test
    void saveCategory_shouldReturnBadRequest_whenProductBlank() throws Exception {
        Map<String, String> body = Map.of("product", "", "category", "hardware_store");

        mockMvc.perform(post("/api/products/category")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isBadRequest());

        verify(productCategoryService, org.mockito.Mockito.never()).saveCategory(anyString(), anyString());
    }

    @Test
    void getCategories_shouldReturnFixedList() throws Exception {
        when(productCategoryService.listCategories()).thenReturn(List.of(PlacesCategory.SUPERMARKET, PlacesCategory.STORE));

        mockMvc.perform(get("/api/products/categories"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].value").value("supermarket"))
                .andExpect(jsonPath("$[0].label").value("Alimentar"));
    }
}
