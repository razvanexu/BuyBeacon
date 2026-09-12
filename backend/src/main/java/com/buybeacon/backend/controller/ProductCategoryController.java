package com.buybeacon.backend.controller;

import com.buybeacon.backend.dto.CategoryLookupResponseDto;
import com.buybeacon.backend.dto.CategoryOptionDto;
import com.buybeacon.backend.dto.SaveCategoryRequestDto;
import com.buybeacon.backend.exception.ApiException;
import com.buybeacon.backend.service.ProductCategoryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

/**
 * Endpoints backing the product-add-time categorization flow: the frontend checks whether
 * a product is already known before adding it, and if not, lets the user pick from the
 * fixed category list and submits that choice back.
 */
@RestController
@RequestMapping("/api/products")
@Tag(name = "Product Category",
        description = "Crowdsourced product-name to shop-category dictionary")
public class ProductCategoryController {

    private final ProductCategoryService productCategoryService;

    public ProductCategoryController(ProductCategoryService productCategoryService) {
        this.productCategoryService = productCategoryService;
    }

    @GetMapping("/category")
    @Operation(summary = "Look up a product's category",
            description = "Checks whether this product name has already been categorized by another user.")
    public ResponseEntity<CategoryLookupResponseDto> getCategory(
            @Parameter(description = "Product name, e.g. \"lapte\"") @RequestParam String product) {
        Optional<String> category = productCategoryService.lookupCategory(product);
        return ResponseEntity.ok(new CategoryLookupResponseDto(category.isPresent(), category.orElse(null)));
    }

    @PostMapping("/category")
    @Operation(summary = "Save a product's category", description = "Submits the user's category pick for a product name not yet in the dictionary.")
    @ApiResponse(responseCode = "200", description = "Saved")
    @ApiResponse(responseCode = "400", description = "Blank product name")
    public ResponseEntity<Void> saveCategory(@RequestBody SaveCategoryRequestDto requestDto) {
        if (requestDto == null || requestDto.product() == null || requestDto.product().isBlank()) {
            throw new ApiException("Product name must not be blank", HttpStatus.BAD_REQUEST);
        }
        productCategoryService.saveCategory(requestDto.product(), requestDto.category());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/categories")
    @Operation(summary = "List all pickable categories",
            description = "Fixed list backing the category-picker UI, one entry per PlacesCategory enum value.")
    public ResponseEntity<List<CategoryOptionDto>> getCategories() {
        List<CategoryOptionDto> options = productCategoryService.listCategories().stream()
                .map(c -> new CategoryOptionDto(c.getCode(), c.getLabel()))
                .toList();
        return ResponseEntity.ok(options);
    }
}
