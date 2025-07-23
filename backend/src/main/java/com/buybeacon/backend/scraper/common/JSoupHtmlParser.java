package com.buybeacon.backend.scraper.common;

import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * A Jsoup-based implementation of the HtmlParser interface.
 * This is the only class that should contain Jsoup-specific parsing logic.
 */
@Component
public class JSoupHtmlParser implements HtmlParser {
    private static final Logger logger = LoggerFactory.getLogger(JSoupHtmlParser.class);

    @Override
    public List<Map<String, String>> parseHtml(String rawHtml, String itemSelector,
                                               Map<String, String> attributeSelectors,
                                               Map<String, String> urlAttribute) {
        Document doc = Jsoup.parse(rawHtml);
        return doc.select(itemSelector).stream()
                .map(item -> parseSingleItem(item, attributeSelectors, urlAttribute))
                .filter(Optional::isPresent)
                .map(Optional::get)
                .toList();
    }

    private Optional<Map<String, String>> parseSingleItem(Element item, Map<String, String> attributeSelectors,
                                                          Map<String, String> urlAttributeSelectors) {
        Map<String, String> itemData = new HashMap<>();

        for (Map.Entry<String, String> entry : attributeSelectors.entrySet()) {
            String key = entry.getKey();
            String selector = entry.getValue();
            Element element = item.selectFirst(selector);

            if (element == null) return Optional.empty();

            String extractedText = "price".equals(key) && element.hasAttr("data-proce-ammpount")
                    ? element.attr("data-price-ammount")
                    : element.text();

            if ("name".equals(key) && !isValidShopName(extractedText)) {
                logger.warn("Filtered out invalid or non-store result: {}", extractedText);
                return Optional.empty();
            }
            itemData.put(key, extractedText);
        }
        for (Map.Entry<String, String> entry : urlAttributeSelectors.entrySet()) {
            String key = entry.getKey();
            String selector = entry.getValue();
            Element element = item.selectFirst(selector);

            if (element == null) return Optional.empty();
            itemData.put(key, element.attr("href"));
        }
        return Optional.of(itemData);


    }

    /**
     * Validates if the extracted text is likely a real store name.
     *
     * @param shopName The text extracted from the search result.
     * @return true if the name is considered valid, false otherwise.
     */
    private boolean isValidShopName(String shopName) {
        if (shopName == null || shopName.isBlank()) {
            return false;
        }
        // Filter out results that are clearly URLs or contain URL-like text
        // or are too long to be a simple store name
        if (shopName.contains(".ro") || shopName.contains(".com")
                || shopName.contains("http") || shopName.contains("www")
                || shopName.length() > 100 || shopName.equalsIgnoreCase("null")) {
            return false;
        }
        // Add any other filtering rules you discover here
        return true;
    }
}
