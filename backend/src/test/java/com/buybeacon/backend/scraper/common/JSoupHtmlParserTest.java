package com.buybeacon.backend.scraper.common;


import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class JSoupHtmlParserTest {
    private JSoupHtmlParser htmlParser;

    @BeforeEach
    void setUp() {
        htmlParser = new JSoupHtmlParser();
    }

    @Test
    void parseHtml_shouldExtractCorrectData_whenHtmlIsValid() {
        // Arrange
        String rawHtml = "<html><body>" +
                "<div class='productItem'>" +
                "<h2 class='productItem-name'><a href='https://example.com/product1'>Product One</a></h2>" +
                "<span class='price price-final' data-price-ammount='10.50'>$10.50</span>" +
                "</div>" +
                "<div class='productItem'>" +
                "<h2 class='productItem-name'><a href='https://example.com/product2'>Product Two</a></h2>" +
                "<span class='price price-final' data-price-ammount='25.00'>$25.00</span>" +
                "</div>" +
                "</body></html>";
        String itemSelector = ".productItem";
        Map<String, String> attributeSelectors = Map.of(
                "name", ".productItem-name a",
                "price", ".price.price-final"
        );
        Map<String, String> urlAttribute = Map.of("url", ".productItem-name a");

        // Act
        List<Map<String, String>> result = htmlParser.parseHtml(rawHtml, itemSelector, attributeSelectors, urlAttribute);

        // Assert
        assertNotNull(result);
        assertEquals(2, result.size());

        Map<String, String> product1 = result.get(0);
        assertEquals("Product One", product1.get("name"));
        assertEquals("10.50", product1.get("price"));
        assertEquals("https://example.com/product1", product1.get("url"));

        Map<String, String> product2 = result.get(1);
        assertEquals("Product Two", product2.get("name"));
        assertEquals("25.00", product2.get("price"));
        assertEquals("https://example.com/product2", product2.get("url"));
    }

    @Test
    void  parse_shouldReturnEmptyList_whenNoItemsMatchSelector(){
        //Arrange
        String rawHtml = "<html><body></body></html>";
        String itemSelector = ".productItem";
        Map<String, String> attributeSelectors = Map.of("name", "a");
        Map<String, String> urlAttribute = Map.of("url", "a");

        //Act
        List<Map<String, String>> result = htmlParser.parseHtml(
                rawHtml, itemSelector, attributeSelectors, urlAttribute);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }
}
