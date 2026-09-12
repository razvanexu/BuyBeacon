package com.buybeacon.backend.controller;

import com.buybeacon.backend.dto.ProductSearchRequestDto;
import com.buybeacon.backend.dto.ShopResponseDto;
import com.buybeacon.backend.service.ShopFinderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "Shop Finder", description = "Resolves product names to nearby shop locations")
public class ShopFinderController {
    private static final Logger logger = LoggerFactory.getLogger(ShopFinderController.class);

    private final ShopFinderService shopFinderService;

    public ShopFinderController(ShopFinderService shopFinderService) {
        this.shopFinderService = shopFinderService;
    }

    /**
     * Endpoint for finding shops based on a list of products.
     *
     * @param requestDto - DTO containing the list of products from front-end
     * @return A response entity containing the list of found shop locations.
     * @PostMapping("/shops/find") maps this method to handle HTTP POST requests to /api/"/shops/find".
     * @RequestBody tells Spring to deserialize the incoming JSON request body
     * into ProductSearchRequestDto object.
     */
    @PostMapping("/shops/find")
    @Operation(summary = "Find shops carrying the given products",
            description = "For each product, resolves its crowdsourced category and searches nearby via Google Places. Returns deduplicated shops, each with the subset of requested products it's expected to carry.")
    @ApiResponse(responseCode = "200", description = "Shops found (possibly empty list)")
    @ApiResponse(responseCode = "400", description = "Empty or missing product list")
    public ResponseEntity<List<ShopResponseDto>> findShops(@RequestBody ProductSearchRequestDto requestDto) {
        // In the final implementation app, with a database, save requestDto.getProducts() for the user.
        // Then, a GET /api/shops endpoint would trigger the findShops logic.
        // For now, the execution of the logic is directly here.
        if (requestDto == null || requestDto.products() == null || requestDto.products().isEmpty()) {
            logger.warn("Received an empty or invalid product search request");
            return ResponseEntity.badRequest().build();
        }

        logger.info("Handling POST request on api/shops/find");
        List<ShopResponseDto> shopLocations = shopFinderService.findShops(
                requestDto.products(), requestDto.latitude(), requestDto.longitude());
        return ResponseEntity.ok(shopLocations);
    }
}
