package com.buybeacon.backend.service;

import com.buybeacon.backend.scraper.common.HtmlFetcher;
import com.buybeacon.backend.scraper.common.HtmlParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
* A basic implementation of the WebSearchService using the JSoup library.
* It performs a Google search and scrapes the results for potential store names.
* NOTE: Web scraping is inherently fragile and can break if the target website's HTML structure changes.
* This implementation is for MVP purposes. A more robust V2 solution would use official APIs or AI.
*/
@Service
public class WebSearchServiceImp implements WebSearchService{
    private static final Logger logger = LoggerFactory.getLogger(WebSearchServiceImp.class);
    private static final String GOOGLE_SEARCH_URL = "https://www.google.com/search?q=";

    private final HtmlFetcher htmlFetcher;
    private final HtmlParser htmlParser;

    @Autowired
    public WebSearchServiceImp(@Qualifier("seleniumHtmlFetcher") HtmlFetcher htmlFetcher, HtmlParser htmlParser) {
        this.htmlFetcher = htmlFetcher;
        this.htmlParser = htmlParser;
    }

    @Override
    public List<String> findShopLocations(String product) {
        List<String> potentialShops;

        if(product == null || product.isBlank()){
            return Collections.emptyList();
        }

        try {
            //Search query with "pret near me" encouragement for local and likely physical stores results.
            String searchQuery = URLEncoder.encode(product + " store near me", StandardCharsets.UTF_8);
            String searchURL = GOOGLE_SEARCH_URL + searchQuery;
            logger.info("Performing web search for product '{}' at URL: {}", product, searchURL);

            String rawHtml = htmlFetcher.fetchHtml(searchURL);
            logger.info("Received page with title for parsing.");

            // span selector
            String itemSelector = "div.MjjYud";
            Map<String, String> attributeSelectors = Map.of("name", "span.VuuXrf");

            List<Map<String, String>> parsedHtml =
                    htmlParser.parseHtml(rawHtml, itemSelector, attributeSelectors, Map.of());

            potentialShops = parsedHtml.stream()
                    .map(data -> data.get("name"))
                    .toList();

            logger.info("Found {} potential shops for product {}", potentialShops.size(), product);

        }catch (IOException ioException){
            logger.error("IOException during web search for product '{}'. This could be a network issue or a block from the server.", product, ioException);
            return Collections.emptyList();
        }
        return potentialShops;
    }
}
