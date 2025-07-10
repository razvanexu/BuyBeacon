package com.buybeacon.backend.scraper;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import javax.swing.text.Document;
import java.io.IOException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;


class CarrefourScraperTest {

    @InjectMocks
    private CarrefourScraper carrefourScraper;

    @Mock
    private HtmlFetcher mockHtmlFetcher;

    @Mock
    private Document mockDocument;

    @BeforeEach
    void setUp(){
        MockitoAnnotations.openMocks(this);
    }

    @Test
    void scrapeProducts_shouldReturnCorrectProducts_whenHtmlIsValid() throws IOException{
        //ARRANGE
        String sampleHtml = "<html><body>" +
                "<div class=\"productItem\">" +
                "  <div class=\"productItem-name\"><a href=\"/product1\">Product One</a></div>" +
                "  <div class=\"productItem-price\"><div class=\"price price-final\" data-price-amount=\"10,50\"></div></div>" +
                "</div>" +
                "<div class=\"productItem\">" +
                "  <div class=\"productItem-name\"><a href=\"/product2\">Product Two</a></div>" +
                "  <div class=\"productItem-price\"><div class=\"price price-final\" data-price-amount=\"20,00\"></div></div>" +
                "</div>" +
                "</body></html>";

        when(mockHtmlFetcher.fetchHtml(anyString())).thenReturn(sampleHtml);

        //ACT
        List<Product> products = carrefourScraper.scrapeProducts("test-query");

        //ASSERT
        assertNotNull(products);
        assertEquals(2, products.size());

        Product product1 = products.get(0);
        assertEquals("Product One", product1.getName());
        assertEquals("10,50", product1.getPrice());
        assertEquals("/product1", product1.getUrl());

        Product product2 = products.get(1);
        assertEquals("Product Two", product2.getName());
        assertEquals("20,00", product2.getPrice());
        assertEquals("/product2", product2.getUrl());
    }

    @Test
    void scrapeProducts_shouldReturnEmptyList_whennoProductIsFound() throws IOException {
        //ARRANGE
        String emptyHtml = "<html><body>No products found</body></html>";
        when(mockHtmlFetcher.fetchHtml(anyString())).thenReturn(emptyHtml);

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
