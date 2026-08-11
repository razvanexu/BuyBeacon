package com.buybeacon.backend.controller;

import com.buybeacon.backend.dto.ShopResponseDto;
import com.buybeacon.backend.service.ShopFinderService;
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

import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;


@SpringBootTest
@AutoConfigureMockMvc
class ShopFinderControllerTest {

    @Autowired
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    private ShopFinderService shopFinderService;
    @Autowired
    private MockMvc mockMvc;
    @InjectMocks
    private ShopFinderController shopFinderController;

    @BeforeEach
    void Setup() {
        mockMvc = MockMvcBuilders.standaloneSetup(shopFinderController).build();
    }

    @Test
    void findShops_shouldReturnCorrectLocations() throws Exception {
        //Arrange

        // 1. Define the data that the mocked service will return
        List<ShopResponseDto> mockShopLocations = List.of(
                new ShopResponseDto("Carrefour Vitan", 44.4, 26.1, List.of("lapte")),
                new ShopResponseDto("Mega Image Unirii", 44.42, 26.11, List.of("lapte"))
        );

        // 2. Program the mock service
        when(shopFinderService.findShops(anyList(), any(), any())).thenReturn(mockShopLocations);

        // 3. Create the HTTP request body
        Map<String, List<String>> requestBody = Map.of("products", List.of("lapte"));

        //Act & Assert
        mockMvc.perform(post("/api/shops/find")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestBody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].storeName").value("Carrefour Vitan"))
                .andExpect(jsonPath("$[1].storeName").value("Mega Image Unirii"));
    }

    @Test
    void findShops_shouldReturnEmptyList_whenServiceReturnsEmpty() throws Exception {
        //Arrange
        when(shopFinderService.findShops(anyList(), any(), any())).thenReturn(Collections.emptyList());
        Map<String, List<String>> requestBody = Map.of("products", List.of("unknown product"));

        //Act & Assert
        mockMvc.perform(post("/api/shops/find")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestBody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void findSHops_shouldReturnBadRequest_whenRequesBodyIsEmpty() throws Exception {
        //ACT & ASSERT
        mockMvc.perform(post("/api/shops/find")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void findShops_ShouldReturnBadRequest_whenProductListIsNull() throws Exception {
        //Act & ASSERT
        mockMvc.perform(post("/api/shops/find")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"products\":null}"))
                .andExpect(status().isBadRequest());
    }
}
