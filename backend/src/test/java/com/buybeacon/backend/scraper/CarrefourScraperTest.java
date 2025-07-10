package com.buybeacon.backend.scraper;

import com.buybeacon.backend.scraper.common.HtmlFetcher;
import com.buybeacon.backend.scraper.common.HtmlParser;
import com.buybeacon.backend.scraper.common.Product;
import com.buybeacon.backend.scraper.retailers.CarrefourScraper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;


class CarrefourScraperTest {

    @InjectMocks
    private CarrefourScraper carrefourScraper;

    @Mock
    private HtmlFetcher mockHtmlFetcher;

    @Mock
    private HtmlParser mockHtmlParser;

    @BeforeEach
    void setUp(){
        MockitoAnnotations.openMocks(this);
    }

    @Test
    void scrapeProducts_shouldReturnCorrectlyMappedProducts() throws IOException{
        //ARRANGE
        List<Map<String, String>> mockParsedData = List.of(
                    Map.of("name", "Product One", "price", "10.50", "url", "https://carrefour.ro/product1"),
                    Map.of("name", "Product Two", "price", "25.00", "url", "https://carrefour.ro/product2")
                );

        when(mockHtmlFetcher.fetchHtml(anyString())).thenReturn("<html><html>"); //return dummy html
        when(mockHtmlParser.parseHtml(anyString(), anyString(), any(Map.class), any(Map.class)))
                .thenReturn(mockParsedData);

        //ACT
        List<Product> products = carrefourScraper.scrapeProducts("test-query");

        //ASSERT
        // Verify that the scraper correctly transformed the parser's output
        assertNotNull(products);
        assertEquals(2, products.size());

        Product product1 = products.get(0);
        assertEquals("Product One", product1.getName());
        assertEquals("10.50", product1.getPrice());
        assertEquals("https://carrefour.ro/product1", product1.getUrl());

        Product product2 = products.get(1);
        assertEquals("Product Two", product2.getName());
        assertEquals("25.00", product2.getPrice());
        assertEquals("https://carrefour.ro/product2", product2.getUrl());
    }

    @Test
    void scrapeProducts_shouldReturnEmptyList_whenNoProductIsFound() throws IOException {
        //ARRANGE
        String emptyHtml = "<html><body>No products found</body></html>";
        List<Map<String, String>> emptylist = new ArrayList<>();

        when(mockHtmlFetcher.fetchHtml(anyString())).thenReturn(emptyHtml);when(mockHtmlParser.parseHtml(anyString(), anyString(), any(Map.class), any(Map.class)))
                .thenReturn(emptylist);

        //ACT
        List<Product> products = carrefourScraper.scrapeProducts("empty-query");

        //ASSERT
        assertNotNull(products);
        assertTrue(products.isEmpty());
    }

    @Test
    void scrapeProducts_shouldThrowIOException_whenHtmlFetchFails() throws IOException {
        //Arrange
        when(mockHtmlFetcher.fetchHtml(anyString())).thenThrow(IOException.class);

        //Act and Assert
        assertThrows(IOException.class, () -> carrefourScraper.scrapeProducts("test-query"));
    }

    @Test
    void supports_shouldReturnTrue_whenRetailerNameMatches() {
        //ARRANGE
        String retailerNameUpperCase = "Carrefour";
        String retailerNameLowerCase = "carrefour";

        //ACT
        boolean resultUpper = carrefourScraper.supports(retailerNameUpperCase);
        boolean resultLower = carrefourScraper.supports(retailerNameLowerCase);

        //ASSERT
        assertTrue(resultUpper);
        assertTrue(resultLower);
    }

    @Test
    void supports_shouldReturnFalse_whenRetailerNameDoesNotMatch() {
        //ARRANGE
        String retailerName = "Not Carrefour";

        //ACT
        boolean result = carrefourScraper.supports(retailerName);

        //ASSERT
        assertFalse(result);
    }
}
