package com.buybeacon.backend;

import com.buybeacon.backend.client.GooglePlacesClient;
import com.buybeacon.backend.service.DiscoveredShop;
import com.buybeacon.backend.service.WebSearchService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.ApplicationContext;
import org.springframework.core.env.Environment;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.in;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.hasItem;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Boots the full application (real controller, real ShopFinderServiceImp, real Spring wiring) and
 * confirms shop discovery works end-to-end with the Carrefour scraper and Selenium gone. Only the
 * outbound sources are mocked: WebSearchService (Places + OSM) and GooglePlacesClient.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ShopDiscoveryWithoutScraperIntegrationTest {

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private ApplicationContext context;
    @Autowired
    private Environment environment;

    @MockitoBean
    private WebSearchService webSearchService;
    @MockitoBean
    private GooglePlacesClient googlePlacesClient;

    @Test
    void contextStartsWithoutAnySeleniumConfiguration() {
        assertFalse(environment.containsProperty("selenium.remote.url"),
                "The app must start without selenium.remote.url being configured");
    }

    @Test
    void noScraperBeansAreRegistered() {
        List<String> scraperBeans = Arrays.stream(context.getBeanDefinitionNames())
                .map(context::getType)
                .filter(Objects::nonNull)
                .map(Class::getName)
                .filter(name -> name.startsWith("com.buybeacon.backend.scraper")
                        || name.contains("Selenium")
                        || name.contains("Jsoup")
                        || name.endsWith("ScraperController"))
                .toList();

        assertTrue(scraperBeans.isEmpty(), "Unexpected scraper beans: " + scraperBeans);
    }

    @Test
    void removedScrapeEndpointReturns404() throws Exception {
        mockMvc.perform(get("/api/scrape/products")
                        .param("query", "lapte")
                        .param("retailerName", "Carrefour"))
                .andExpect(status().isNotFound());
    }

    @Test
    void findShopsReturnsPlacesAndOsmShopsEndToEnd() throws Exception {
        when(webSearchService.findShopLocations("lapte", 44.456, 26.073)).thenReturn(List.of(
                new DiscoveredShop("Carrefour Market Domenii", 44.4570, 26.0740, "placeA"),
                new DiscoveredShop("Mic magazin", 44.4565, 26.0725, "osm:node:42")));
        when(webSearchService.findShopLocations("paine", 44.456, 26.073)).thenReturn(List.of(
                new DiscoveredShop("Carrefour Market Domenii", 44.4570, 26.0740, "placeA"),
                new DiscoveredShop("Mega Image", 44.4550, 26.0710, "placeB")));

        mockMvc.perform(post("/api/shops/find")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"products":["lapte","paine"],"latitude":44.456,"longitude":26.073}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[*].storeName",
                        containsInAnyOrder("Carrefour Market Domenii", "Mic magazin", "Mega Image")))
                // The shop found for both products is one pin carrying both products.
                .andExpect(jsonPath("$[?(@.storeName == 'Carrefour Market Domenii')].products[*]",
                        containsInAnyOrder("lapte", "paine")))
                .andExpect(jsonPath("$[?(@.storeName == 'Carrefour Market Domenii')].latitude")
                        .value(hasItem(44.4570)))
                // Only the two remaining discovery sources may appear.
                .andExpect(jsonPath("$[*].source", everyItem(in(List.of("google_places", "openstreetmap")))))
                .andExpect(jsonPath("$[*].source", not(hasItem("retailer_catalog"))))
                .andExpect(jsonPath("$[*].matchConfidence", everyItem(in(List.of("CATEGORY_MATCH")))));

        // Coordinates come straight from discovery: nothing else asks Places to geocode a name.
        verifyNoInteractions(googlePlacesClient);
    }

    @Test
    void findShopsReturnsEmptyListWhenNoSourceFindsAnything() throws Exception {
        when(webSearchService.findShopLocations(anyString(), any(), any())).thenReturn(List.of());

        mockMvc.perform(post("/api/shops/find")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"products":["lapte"],"latitude":44.456,"longitude":26.073}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        // Previously an empty discovery could still yield a geocoded Carrefour pin; now nothing
        // else is consulted.
        verifyNoInteractions(googlePlacesClient);
    }
}
