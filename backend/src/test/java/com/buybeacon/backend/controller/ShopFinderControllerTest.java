package com.buybeacon.backend.controller;

import com.buybeacon.backend.dto.ShopLocationDto;
import com.buybeacon.backend.service.ShopFinderService;
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

import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;


@SpringBootTest
@AutoConfigureMockMvc
class ShopFinderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Mock
    private ShopFinderService shopFinderService;

    @InjectMocks
    private ShopFinderController shopFinderController;

    @BeforeEach
    void Setup(){
        mockMvc = MockMvcBuilders.standaloneSetup(shopFinderController).build();
    }

    @Test
    void findShops_shouldReturnCorrectLocations() throws Exception{
        //Arrange

        // 1. Define the data that the mocked service will return
        List<ShopLocationDto> mockShopLocations = List.of(
                new ShopLocationDto("Carrefour Vitan", 44.4, 26.1),
                new ShopLocationDto("Mega Image Unirii", 44.42, 26.11)
        );

        // 2. Program the mock service
        when(shopFinderService.findShops(anyList())).thenReturn(mockShopLocations);

        // 3. Create the HTTP request body
        String requestBody = "{\"products\":[\"lapte\"]}";

        //Act & Assert
        mockMvc.perform(post("/api/shops/find")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].storeName").value("Carrefour Vitan"))
                .andExpect(jsonPath("$[1].storeName").value("Mega Image Unirii"));
    }

    @Test
    void findShops_shouldReturnEmptyList_whenServiceReturnsEmpty() throws Exception{
        //Arrange
        when(shopFinderService.findShops(anyList())).thenReturn(List.of());
        String requestBody = "{ \"products\": [\"unknown_product\"] }";

        //Act & Assert
        mockMvc.perform(post("/api/shops/find")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(0));
    }
}
