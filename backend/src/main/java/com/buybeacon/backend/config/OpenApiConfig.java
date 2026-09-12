package com.buybeacon.backend.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    public OpenAPI buyBeaconOpenApi() {
        return new OpenAPI().info(new Info()
                .title("BuyBeacon API")
                .version("v1")
                .description(
                        "Location-aware shopping list backend: " +
                                "shop discovery via Google Places and crowdsourced" +
                                " product-category lookup."));
    }
}
