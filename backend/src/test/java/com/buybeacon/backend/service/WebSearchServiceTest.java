package com.buybeacon.backend.service;

import com.buybeacon.backend.scraper.common.HtmlFetcher;
import com.buybeacon.backend.scraper.common.HtmlParser;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WebSearchServiceTest {
    @Mock
    private HtmlFetcher htmlFetcher;

    @Mock
    private HtmlParser htmlParser;

    @InjectMocks
    private WebSearchServiceImp webSearchService;

    @Test
    void findShopLocations_shouldReturnListOfShops_whenScrapingSuccessful() throws IOException {
        //ARRANGE
        String product = "printer ink";
        String encodedQuery = URLEncoder.encode(product + " store near me", StandardCharsets.UTF_8);
        String expectedUrl = "https://www.google.com/search?q=" + encodedQuery;
        String dummyHtml = "<html><body><div><span class='VuuXrf'>Shop A</span></div><div><span class='VuuXrf'>Shop " +
                "B</span></div></body></html>";

        List<Map<String, String>> parsedData = List.of(
                Map.of("name", "Shop A"),
                Map.of("name", "Shop B")
        );

        when(htmlFetcher.fetchHtml(expectedUrl)).thenReturn(dummyHtml);
        when(htmlParser.parseHtml(eq(dummyHtml), anyString(), any(Map.class), any(Map.class))).thenReturn(parsedData);

        //ACT
        List<String> result = webSearchService.findShopLocations(product);

        //ASSERT
        assertNotNull(result);
        assertEquals(2, result.size());
        assertEquals("Shop A", result.get(0));
        assertEquals("Shop B", result.get(1));

        verify(htmlFetcher).fetchHtml(expectedUrl);
    }

    @Test
    void findShopLocations_shouldReturnEmptyList_whenIOExeptionOccurs() throws IOException {
        //ARRANGE
        String product = "printer ink";
        when(htmlFetcher.fetchHtml(anyString())).thenThrow(new IOException("Network Error"));

        //ACT
        List<String> result = webSearchService.findShopLocations(product);

        //ASSERT
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void findSopLocations_shouldshouldReturnEmptyList_whenNullOrBlakProduct() {
        //ARRANGE


        //ACT
        List<String> resultsForNull = webSearchService.findShopLocations(null);
        List<String> resultsForBlank = webSearchService.findShopLocations("  ");

        //ASSERT
        assertNotNull(resultsForNull);
        assertTrue(resultsForNull.isEmpty());
        assertNotNull(resultsForBlank);
        assertTrue(resultsForBlank.isEmpty());
    }
}
