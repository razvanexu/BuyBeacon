package com.buybeacon.backend.controller;

import com.buybeacon.backend.dto.ProductSearchRequestDto;
import com.buybeacon.backend.dto.ShopLocationDto;
import com.buybeacon.backend.service.ShopFinderService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Main REST controller for the application.
 * Defines public API endpoints for the mobile app.
 */
@RestController
@RequestMapping("/api")
public class ShopFinderController {
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderController.class);

    private final ShopFinderService shopFinderService;

    public ShopFinderController(ShopFinderService shopFinderService) {
        this.shopFinderService = shopFinderService;
    }

    /**
     * Endpoint for finding shops based on a list of products.
     *
     * @PostMapping("/shops/find") maps this method to handle HTTP POST requests to /api/"/shops/find".
     *
     * @RequestBody tells Spring to deserialize the incoming JSON request body
     * into ProductSearchRequestDto object.
     *
     * @param requestDto - DTO containing the list of products from front-end
     * @return A response entity containing the list of found shop locations.
     */
    @PostMapping("/shops/find")
    public ResponseEntity<List<ShopLocationDto>> findShops(@RequestBody ProductSearchRequestDto requestDto){
        // In the final implementation app, with a database, save requestDto.getProducts() for the user.
        // Then, a GET /api/shops endpoint would trigger the findShops logic.
        // For now, the execution of the logic is directly here.
        if(requestDto == null || requestDto.products() == null || requestDto.products().isEmpty()){
            logger.warn("Received an empty or invalid product search request");
            return ResponseEntity.badRequest().build();
        }

        logger.info("Handling POST request on api/reminders");
        List<ShopLocationDto> shopLocations = shopFinderService.findShops(requestDto.products());
        return ResponseEntity.ok(shopLocations);
    }
}
