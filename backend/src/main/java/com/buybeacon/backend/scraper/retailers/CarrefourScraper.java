package com.buybeacon.backend.scraper.retailers;

import com.buybeacon.backend.scraper.common.HtmlFetcher;
import com.buybeacon.backend.scraper.common.HtmlParser;
import com.buybeacon.backend.scraper.common.Product;
import com.buybeacon.backend.scraper.orchestration.RetailerScraper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * A specific scraper for Carrefour.ro.
 * This class is responsible for configuration (URL, selectors)
 * and orchestrating the fetch and parse operations.
 */
@Component
public class CarrefourScraper implements RetailerScraper {

    private static final String CARREFOUR_SEARCH_URL = "https://carrefour.ro/catalogsearch/result/?q=";
    private static final String RETAILER_NAME = "Carrefour";
    private final HtmlFetcher htmlFetcher;
    private final HtmlParser htmlParser;

    @Autowired
    public  CarrefourScraper(HtmlFetcher htmlFetcher, HtmlParser htmlParser){
        this.htmlFetcher = htmlFetcher;
        this.htmlParser = htmlParser;
    }

    @Override
    public List<Product> scrapeProducts(String query) throws IOException {
        String searchUrl = CARREFOUR_SEARCH_URL + query;
        //Fetch raw Html
        String rawHtml = htmlFetcher.fetchHtml(searchUrl);
        // Define the selectors specific to Carrefour's search results page
        String itemSelector = ".productItem";
        Map<String, String> attributeSelectors = Map.of(
                "name", ".productItem-name a",
                "price", ".price.price-final"
        );

        Map<String, String> urlAttribute  = Map.of("url", ".productItem-name a");

        //delegate parsing to htmlParser
        List<Map<String, String>> parsedData = htmlParser.parseHtml(
                                                    rawHtml, itemSelector, attributeSelectors, urlAttribute);

        //Transform generic data into a list of products;
        return parsedData.stream()
                .map(data -> new Product(
                        data.get("name"),
                        data.get("price"),
                        data.get("url")
                    )
                )
                .collect(Collectors.toList());
    }
    @Override
    public boolean supports(String retailerName) {
        return RETAILER_NAME.equalsIgnoreCase(retailerName);
    }
}
