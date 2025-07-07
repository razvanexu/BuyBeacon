package com.buybeacon.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.jsoup.select.Elements;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
* A basic implementation of the WebSearchService using the JSoup library.
* It performs a Google search and scrapes the results for potential store names.
*
* NOTE: Web scraping is inherently fragile and can break if the target website's HTML structure changes.
* This implementation is for MVP purposes. A more robust V2 solution would use official APIs or AI.
*/
@Service
public class WebSearchServiceImp implements WebSearchService{
    private static final Logger logger = LoggerFactory.getLogger(WebSearchServiceImp.class);
    private static final String GOOGLE_SEARCH_URL = "https://www.google.com/search?q=";

    @Override
    public List<String> findShopLocations(String product) {
        if(product == null || product.isBlank()){
            return Collections.emptyList();
        }

        List<String> potentialShops = new ArrayList<>();
        try {
            //Search query with "near me" encouragement for local results.
            String searchQuery = URLEncoder.encode(product + " stores near me", StandardCharsets.UTF_8);
            String searchURL = GOOGLE_SEARCH_URL + searchQuery;

            logger.info("Performing web search for product '{}' at URL: {}", product, searchURL);

            //fetch HTML from Google. Set a User-Agent to mimic real browser.
            Document doc = Jsoup.connect(searchURL)
                    .userAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36")
                    .get();

            // *** CRITICAL DEBUGGING STEP ***
            // Log the title of the page we received. This tells us if we're on a real search results page or a CAPTCHA page.
            logger.info("Received page with title: '{}'", doc.title());
            // span selector
            Elements searchResults = doc.select("span.OSrXXb");

            for (Element result : searchResults){
                potentialShops.add(result.text());
                logger.info("Found {} potential shops for product {}", potentialShops.size(), product);
            }
        }catch (IOException ioException){
            logger.error("IOException during web search for product '{}'. This could be a network issue or a block from the server.", product, ioException);
            return Collections.emptyList();
        }
        return potentialShops;
    }
}
