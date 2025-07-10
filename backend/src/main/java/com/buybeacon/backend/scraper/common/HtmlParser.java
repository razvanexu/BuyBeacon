package com.buybeacon.backend.scraper.common;

import java.util.List;
import java.util.Map;

public interface HtmlParser {
    /**
     * Parses a raw HTML string to extract a list of items, where each item is
     * represented as a map of its extracted data.
     *
     * @param rawHtml The HTML content to parse.
     * @param itemSelector The CSS selector to identify the container for each individual item.
     * @param attributeSelectors A map where the key is the desired attribute name (e.g., "name", "price")
     *                           and the value is the CSS selector to find that attribute within an item container.
     * @param urlAttribute A map specifying which attribute should be used to extract a URL,
     *                     where the key is the attribute name (e.g., "url") and the value is the CSS selector.
     * @return A list of maps, where each map represents a parsed item.
     */
    List<Map<String, String>> parseHtml(String rawHtml, String itemSelector, Map<String,
            String> attributeSelectors, Map<String, String> urlAttribute);
}
