package com.buybeacon.backend.controller;

import com.buybeacon.backend.dto.CategoryLookupResponseDto;
import com.buybeacon.backend.dto.CategoryOptionDto;
import com.buybeacon.backend.dto.SaveCategoryRequestDto;
import com.buybeacon.backend.exception.ApiException;
import com.buybeacon.backend.service.ProductCategoryService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Optional;

/**
 * Endpoints backing the product-add-time categorization flow: the frontend checks whether
 * a product is already known before adding it, and if not, lets the user pick from the
 * fixed category list and submits that choice back.
 */
@RestController
@RequestMapping("/api/products")
public class ProductCategoryController {

    private final ProductCategoryService productCategoryService;

    public ProductCategoryController(ProductCategoryService productCategoryService) {
        this.productCategoryService = productCategoryService;
    }

    @GetMapping("/category")
    public ResponseEntity<CategoryLookupResponseDto> getCategory(@RequestParam String product) {
        Optional<String> category = productCategoryService.lookupCategory(product);
        return ResponseEntity.ok(new CategoryLookupResponseDto(category.isPresent(), category.orElse(null)));
    }

    @PostMapping("/category")
    public ResponseEntity<Void> saveCategory(@RequestBody SaveCategoryRequestDto requestDto) {
        if (requestDto == null || requestDto.product() == null || requestDto.product().isBlank()) {
            throw new ApiException("Product name must not be blank", HttpStatus.BAD_REQUEST);
        }
        productCategoryService.saveCategory(requestDto.product(), requestDto.category());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/categories")
    public ResponseEntity<List<CategoryOptionDto>> getCategories() {
        List<CategoryOptionDto> options = productCategoryService.listCategories().stream()
                .map(c -> new CategoryOptionDto(c.getCode(), c.getLabel()))
                .toList();
        return ResponseEntity.ok(options);
    }
}
